public with sharing class ArticleAIProcessor {

    private static String getApiKey(){
        API_Settings__c settings = API_Settings__c.getOrgDefaults();//fetches the custom setting record
        return settings.Groq_API_Key__c;
    }

    public static List<News_Article__c> getUnprocessedArticles (){

        return[SELECT id,Title__c,Description__c from News_Article__c where Is_Processed__c = false And Title__c != null  LIMIT 10];
    }

    //method for http callout 
    public static String callGroqApi(String title, String description){

        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.groq.com/openai/v1/chat/completions');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + getApiKey());

        String prompt = 'Analyze this news article and respond in exactly this format:\\nSENTIMENT: [Positive/Negative/Neutral]\\nSCORE: [0.0 to 1.0]\\nSUMMARY: [2 sentence summary]\\n\\nTitle: ' + title + '\\nDescription: ' + description;

        String body = '{"model":"llama-3.1-8b-instant","messages":[{"role":"user","content":"' + prompt + '"}]}';

        req.setBody(body);

        HttpResponse res = new Http().send(req);
        return res.getBody();
    }

    public class GroqResponse{

    }

    public class GroqChoice{

    }

    public class GroqMessage{
        
    }
}