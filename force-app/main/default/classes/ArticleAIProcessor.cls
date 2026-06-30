public with sharing class ArticleAIProcessor implements Queueable, Database.AllowsCallouts {

    // reads Groq API key from Custom Settings — never hardcode keys in Apex
    private static String getApiKey(){
        API_Settings__c settings = API_Settings__c.getInstance();
        return settings.Groq_API_Key2__c;
    }

    // queries unprocessed articles — LIMIT 20 to stay within Groq rate limits
    // also fetches Region__c so we can link Crisis_Event__c to the correct region
    public static List<News_Article__c> getUnprocessedArticles(){
        return [SELECT Id, Title__c, Description__c, Region__c FROM News_Article__c 
                WHERE Is_Processed__c = false AND Title__c != null LIMIT 20];
    }

    // makes HTTP POST callout to Groq AI API
    // takes article title and description, returns raw JSON response string
    // prompt asks for sentiment, score, summary AND event classification in one call
    public static String callGroqApi(String title, String description){

        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.groq.com/openai/v1/chat/completions');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + getApiKey());

        // sanitize input — remove newlines and quotes that break JSON string
        String cleanTitle = title != null ? title.replaceAll('[\\n\\r"]', ' ') : '';
        String cleanDescription = description != null ? description.replaceAll('[\\n\\r"]', ' ') : '';

        // expanded prompt — asks for sentiment + event classification in one API call
        // saves Groq API calls vs making two separate requests
        String prompt = 'Analyze this news article and respond in exactly this format:\\nSENTIMENT: [Positive/Negative/Neutral]\\nSCORE: [0.0 to 1.0]\\nSUMMARY: [2 sentence summary]\\nEVENT_TYPE: [Military/Diplomatic/Economic/Cyber]\\nSEVERITY: [Low/Medium/High/Critical]\\nEVENT_SUMMARY: [1 sentence event description]\\n\\nTitle: ' + cleanTitle + '\\nDescription: ' + cleanDescription;

        // build JSON body with model name and prompt
        String body = '{"model":"llama-3.1-8b-instant","messages":[{"role":"user","content":"' + prompt + '"}]}';

        req.setBody(body);

        HttpResponse res = new Http().send(req);
        return res.getBody();
    }

    // wrapper classes to map Groq JSON response structure
    // GroqResponse → GroqChoice → GroqMessage → content (the actual AI text)
    public class GroqResponse {
        public List<GroqChoice> choices; // maps the "choices" array in Groq JSON
    }

    public class GroqChoice {
        public GroqMessage message; // maps the "message" object inside each choice
    }

    public class GroqMessage {
        public String content; // maps the "content" field — this is our actual AI response text
    }

    public static void processArticles() {
    
        // Step 1: Get all unprocessed articles — max 20 at a time
        List<News_Article__c> articles = getUnprocessedArticles();
        
        // Step 2: Lists to hold updated records for bulk DML — never do DML inside a loop
        List<News_Article__c> articlesToUpdate = new List<News_Article__c>();
        List<Crisis_Event__c> eventsToInsert = new List<Crisis_Event__c>();
        
        // Step 3: Loop through each article
        for(News_Article__c article : articles) {
            
            try {
                // Step 4: Call Groq API with sanitized title and description
                String responseBody = callGroqApi(article.Title__c, article.Description__c);
                
                // Step 5: Log raw response for debugging
                System.debug('Groq Response: ' + responseBody);
                
                // Step 6: Parse JSON response into wrapper class
                GroqResponse gr = (GroqResponse)JSON.deserialize(responseBody, GroqResponse.class);
                
                // Step 7: Extract the content text from nested wrapper classes
                String content = gr.choices[0].message.content;
                
                // Step 8: Split content by newline to get each line
                // Line 0 = SENTIMENT, Line 1 = SCORE, Line 2 = SUMMARY
                // Line 3 = EVENT_TYPE, Line 4 = SEVERITY, Line 5 = EVENT_SUMMARY
                List<String> lines = content.split('\n');
                
                // Step 9: Extract sentiment and normalize to valid picklist values
                String sentiment = lines[0].split(': ')[1].trim();

                // normalize sentiment — Groq sometimes returns variations like "Mixed/Negative"
                // map everything to valid picklist values: Positive, Negative, Neutral
                if(sentiment.containsIgnoreCase('Positive')) {
                    sentiment = 'Positive';
                } else if(sentiment.containsIgnoreCase('Negative')) {
                    sentiment = 'Negative';
                } else {
                    sentiment = 'Neutral';
                }

                String score = lines[1].split(': ')[1].trim();
                String summary = lines[2].split(': ')[1].trim();

                // Step 10: Extract event classification fields
                String eventType = lines[3].split(': ')[1].trim();
                String severity = lines[4].split(': ')[1].trim();
                String eventSummary = lines[5].split(': ')[1].trim();

                // normalize event type — if Groq returns unexpected value, default to Diplomatic
                if(!new List<String>{'Military','Diplomatic','Economic','Cyber'}.contains(eventType)) {
                    eventType = 'Diplomatic';
                }

                // normalize severity — if Groq returns unexpected value, default to Medium
                if(!new List<String>{'Low','Medium','High','Critical'}.contains(severity)) {
                    severity = 'Medium';
                }
                
                // Step 11: Update the article record fields
                article.Sentiment__c = sentiment;
                article.Sentiment_Score__c = Decimal.valueOf(score); // convert String "0.75" to Decimal
                article.AI_Summary__c = summary;
                article.Is_Processed__c = true; // mark as processed so we don't process again
                
                // Step 12: Add to update list
                articlesToUpdate.add(article);

                // Step 13: Auto-create Crisis_Event__c for significant negative articles
                // only create event if sentiment is Negative AND score is above 0.7
                // this filters out minor negative articles and focuses on real crises
                if(sentiment == 'Negative' && Decimal.valueOf(score) > 0.7) {
                    Crisis_Event__c crisisEvent = new Crisis_Event__c();
                    crisisEvent.Event_Type__c = eventType;
                    crisisEvent.Severity__c = severity;
                    crisisEvent.Summary__c = eventSummary;
                    crisisEvent.Event_Date__c = Date.today();
                    crisisEvent.Region__c = article.Region__c;
                    eventsToInsert.add(crisisEvent);
                }
                
            } catch(Exception e) {
                // if one article fails, log and continue to next — don't crash everything
                System.debug('Error processing article: ' + article.Title__c + ' — ' + e.getMessage());
            }
        }
        
        // Step 14: Bulk update all articles in one DML operation — governor limit best practice
        if(articlesToUpdate.size() > 0) {
            update articlesToUpdate;
        }

        // Step 15: Bulk insert all crisis events in one DML operation
        if(eventsToInsert.size() > 0) {
            insert eventsToInsert;
        }

        // Step 16: Self chain — if unprocessed articles still exist, queue another run
        // this ensures all articles get processed without waiting for next scheduler run
        // placed outside the update block so it runs even if all articles failed processing
        Integer remaining = [SELECT COUNT() FROM News_Article__c WHERE Is_Processed__c = false AND Title__c != null];
        if(remaining > 0) {
            System.enqueueJob(new ArticleAIProcessor());
        }
    }

    // execute() is called by Salesforce when this Queueable job runs
    // it simply calls processArticles() to do the actual work
    public void execute(QueueableContext context) {
        processArticles();
    }
}