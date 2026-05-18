public with sharing class ArticleAIProcessor  implements Queueable, Database.AllowsCallouts {

    private static String getApiKey(){
        API_Settings__c settings = API_Settings__c.getInstance(); // fetches the custom setting record
        return settings.Groq_API_Key2__c;
    }

    public static List<News_Article__c> getUnprocessedArticles(){
        return [SELECT Id, Title__c, Description__c FROM News_Article__c 
                WHERE Is_Processed__c = false AND Title__c != null LIMIT 10];
    }

    // method for http callout to Groq AI API
    public static String callGroqApi(String title, String description){

        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.groq.com/openai/v1/chat/completions');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + getApiKey()); // reads key from custom settings

        // prompt tells Groq exactly what format to respond in
        String cleanTitle = title != null ? title.replaceAll('[\\n\\r"]', ' ') : '';
        String cleanDescription = description != null ? description.replaceAll('[\\n\\r"]', ' ') : '';

        String prompt = 'Analyze this news article and respond in exactly this format:\\nSENTIMENT: [Positive/Negative/Neutral]\\nSCORE: [0.0 to 1.0]\\nSUMMARY: [2 sentence summary]\\n\\nTitle: ' + cleanTitle + '\\nDescription: ' + cleanDescription;

        // build the JSON body with model and prompt
        String body = '{"model":"llama-3.1-8b-instant","messages":[{"role":"user","content":"' + prompt + '"}]}';

        req.setBody(body);

        HttpResponse res = new Http().send(req); // send request and get response
        return res.getBody(); // return raw JSON string
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
    
        // Step 1: Get all unprocessed articles
        List<News_Article__c> articles = getUnprocessedArticles();
        
        // Step 2: List to hold updated articles for bulk DML — never do DML inside a loop
        List<News_Article__c> articlesToUpdate = new List<News_Article__c>();
        
        // Step 3: Loop through each article
        for(News_Article__c article : articles) {
            
            try {
                // Step 4: Call Groq API with title and description
                String responseBody = callGroqApi(article.Title__c, article.Description__c);
                
                // Step 5: Log raw response for debugging
                System.debug('Groq Response: ' + responseBody);
                
                // Step 6: Parse JSON response into wrapper class
                GroqResponse gr = (GroqResponse)JSON.deserialize(responseBody, GroqResponse.class);
                
                // Step 7: Extract the content text from nested wrapper classes
                String content = gr.choices[0].message.content;
                
                // Step 8: Split content by newline to get each line
                // Line 0 = SENTIMENT, Line 1 = SCORE, Line 2 = SUMMARY
                List<String> lines = content.split('\n');
                
                // Step 9: Extract value after ": " for each line
                String sentiment = lines[0].split(': ')[1].trim();

                if(sentiment.containsIgnoreCase('Positive')) {
                    sentiment = 'Positive';
                } else if(sentiment.containsIgnoreCase('Negative')) {
                    sentiment = 'Negative';
                } else {
                    sentiment = 'Neutral';
                }

                String score = lines[1].split(': ')[1].trim();
                String summary = lines[2].split(': ')[1].trim();
                
                // Step 10: Update the article record fields
                article.Sentiment__c = sentiment;
                article.Sentiment_Score__c = Decimal.valueOf(score); // convert String "0.75" to Decimal
                article.AI_Summary__c = summary;
                article.Is_Processed__c = true; // mark as processed so we don't process again
                
                // Step 11: Add to update list
                articlesToUpdate.add(article);
                
            } catch(Exception e) {
                // if one article fails, log and continue to next — don't crash everything
                System.debug('Error processing article: ' + article.Title__c + ' — ' + e.getMessage());
            }
        }
        
        // Step 12: Bulk update all articles in one DML operation — governor limit best practice
        if(articlesToUpdate.size() > 0) {
            update articlesToUpdate;

            // Step 13: Self chain — if unprocessed articles still exist, queue another run
            // this ensures all articles get processed without waiting for next scheduler run
            Integer remaining = [SELECT COUNT() FROM News_Article__c WHERE Is_Processed__c = false AND Title__c != null];
            if(remaining > 0) {
                System.enqueueJob(new ArticleAIProcessor());
            }
        }
    }

    public void execute(QueueableContext context) {
    processArticles();
}
}