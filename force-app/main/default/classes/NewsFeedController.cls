public with sharing class NewsFeedController {

    @AuraEnabled(cacheable=true)
    public static List<Crisis_Event__c> getEvents(String regionName){

        return [SELECT Event_Date__c,Event_Type__c,Severity__c,Summary__c,Source_URL__c,Region__c from Crisis_Event__c WHERE Region__r.Name = :regionName ORDER By Event_Date__c DESC ];
    } 

    @AuraEnabled(cacheable=true)
    public static List<Region__c> getRegions() {
    return [SELECT Id,Name,Latitude__c,Longitude__c,Threat_Level__c FROM Region__c ORDER BY Name];
}   
    
    @AuraEnabled(cacheable=true)
    public static List<News_Article__c> getNews(String region){

        return [SELECT Name,Region__r.Name,Is_Processed__c,Published_At__c,Region__c,Sentiment__c,Sentiment_Score__c,Source_Name__c,Title__c,URL__c,Description__c,Crisis_Event__c  From News_Article__c where Region__r.Name =:region ORDER BY Published_At__c DESC LIMIT 50];
    }

    @AuraEnabled (cacheable=true)
    public static List<AggregateResult> getSentimentCounts(String region){
        return [SELECT Sentiment__c, COUNT(Id) total FROM News_Article__c WHERE Region__r.Name = :region AND Is_Processed__c = true GROUP BY Sentiment__c];
    }

    @AuraEnabled // no cacheable because this method writes data 
    public static void createRegion(String name, Decimal latitude, Decimal longitude, String threatLevel, String searchQuery) {
        Region__c newRegion = new Region__c();
        newRegion.Name = name;
        newRegion.Latitude__c = latitude;
        newRegion.Longitude__c = longitude;
        newRegion.Threat_Level__c = threatLevel;
        newRegion.Search_Query__c = searchQuery;

        insert newRegion;
    }

    @AuraEnabled
    public static void fetchNewsForRegion(String regionName) {
        System.enqueueJob(new NewsApiCallout(regionName));
    }

    @AuraEnabled
    public static Map<String, String> lookupRegion(String regionName) {
        
        Map<String, String> result = new Map<String, String>();
        
        // Step 1 — Call Nominatim for coordinates
        String nominatimUrl = 'https://nominatim.openstreetmap.org/search?q=' + 
                            EncodingUtil.urlEncode(regionName, 'UTF-8') + 
                            '&format=json&limit=1';
        
        HttpRequest nominatimReq = new HttpRequest();
        nominatimReq.setEndpoint(nominatimUrl);
        nominatimReq.setMethod('GET');
        nominatimReq.setHeader('User-Agent', 'GlobalCrisisTracker/1.0');
        nominatimReq.setTimeout(10000);
        
        HttpResponse nominatimRes = new Http().send(nominatimReq);
        
        if(nominatimRes.getStatusCode() == 200) {
            List<Object> data = (List<Object>)JSON.deserializeUntyped(nominatimRes.getBody());
            if(!data.isEmpty()) {
                Map<String, Object> location = (Map<String, Object>)data[0];
                result.put('latitude', String.valueOf(location.get('lat')));
                result.put('longitude', String.valueOf(location.get('lon')));
                result.put('displayName', String.valueOf(location.get('display_name')));
            }
        }
        
        // Step 2 — Call Groq for threat level and search query
        API_Settings__c settings = API_Settings__c.getInstance();
        String groqKey = settings.Groq_API_Key2__c;
        
        String prompt = 'For the region "' + regionName + '", respond in exactly this format:\\nTHREAT_LEVEL: [Critical/High/Medium/Low]\\nSEARCH_QUERY: [5-8 word news search query for crisis news]';
        
        String groqBody = '{"model":"llama-3.1-8b-instant","messages":[{"role":"user","content":"' + prompt + '"}]}';
        
        HttpRequest groqReq = new HttpRequest();
        groqReq.setEndpoint('https://api.groq.com/openai/v1/chat/completions');
        groqReq.setMethod('POST');
        groqReq.setHeader('Content-Type', 'application/json');
        groqReq.setHeader('Authorization', 'Bearer ' + groqKey);
        groqReq.setTimeout(10000);
        groqReq.setBody(groqBody);
        
        HttpResponse groqRes = new Http().send(groqReq);
        
        if(groqRes.getStatusCode() == 200) {
            Map<String, Object> groqData = (Map<String, Object>)JSON.deserializeUntyped(groqRes.getBody());
            List<Object> choices = (List<Object>)groqData.get('choices');
            Map<String, Object> choice = (Map<String, Object>)choices[0];
            Map<String, Object> message = (Map<String, Object>)choice.get('message');
            String content = (String)message.get('content');
            
            List<String> lines = content.split('\n');
            for(String line : lines) {
                if(line.startsWith('THREAT_LEVEL:')) {
                    result.put('threatLevel', line.split(': ')[1].trim());
                }
                if(line.startsWith('SEARCH_QUERY:')) {
                    result.put('searchQuery', line.split(': ')[1].trim());
                }
            }
        }
        
        return result;
    }
}