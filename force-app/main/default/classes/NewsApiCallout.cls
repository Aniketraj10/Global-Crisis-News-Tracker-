public class NewsApiCallout implements Queueable, Database.AllowsCallouts {

    private String regionName;

    public NewsApiCallout(String regionName) {
        this.regionName = regionName;//constructor
    }

    public void execute(QueueableContext context) {

        Region__c region = [SELECT Id, Name FROM Region__c WHERE Name = :regionName LIMIT 1];

        API_Settings__c settings = API_Settings__c.getInstance();
        // getOrgDefaults() — this is a built-in method for Hierarchy Custom Settings that fetches the org level value
        
        String apiKey = settings.NewsAPI_Key__c;

        String query = EncodingUtil.urlEncode(regionName, 'UTF-8');
        //EncodingUtil.urlEncode() — converts region name to URL safe format, so "Persian Gulf" becomes "Persian+Gulf" automatically


        String endpoint = 'https://newsapi.org/v2/everything?q='+ query + '&language=en&sortBy=publishedAt&apiKey=' + apiKey;

        Http http = new Http();//Salesforce class that handles HTTP connections
        HttpRequest request = new HttpRequest();// represents the request we're sending
        request.setEndpoint(endpoint);//the NewsAPI URL with your parameters
        request.setMethod('GET');// we're fetching data, so GET
        request.setTimeout(120000);//wait up to 120 seconds for a response

        HttpResponse response = http.send(request);//stores whatever NewsAPI sends back

        if(response.getStatusCode() == 200) {
        NewsAPIWrapper newResponse =(NewsAPIWrapper)JSON.deserialize(response.getBody(),NewsAPIWrapper.class);

        System.debug('Total articles: ' + newResponse.totalResults);
        System.debug('First article title: ' + newResponse.articles[0].title);
        
        
        //collect all Urls from Api response
        Set<String> incomingURLs = new Set<String>();
        for(NewsAPIWrapper.Article article : newResponse.articles) {
            incomingURLs.add(article.url);
        }
        
        //query existing articles with thosa ulr
        Set<String> existingURLs = new Set<String>();
        for(News_Article__c existing : [SELECT URL__c FROM News_Article__c WHERE URL__c IN :incomingURLs]) {
            existingURLs.add(existing.URL__c);
        }

        //only insert if URL dosent't alredy exist  
        List<News_Article__c> articlesToInsert  = new List<News_Article__c>();
        for(NewsAPIWrapper.Article article : newResponse.articles){
            if(!existingURLs.contains(article.url)){
                News_Article__c newArticle = new News_Article__c();

                newArticle.Title__c = article.title;

                newArticle.Description__c = article.description;

                newArticle.URL__c = article.url;

                newArticle.Published_At__c = DateTime.valueOf(article.publishedAt.replace('T', ' ').replace('Z', ''));

                newArticle.Source_Name__c = article.source.name;

                newArticle.Region__c = region.Id;
                
                articlesToInsert.add(newArticle);
            }
        }
        insert articlesToInsert;

        System.debug('Inserted articles: ' + articlesToInsert.size());

        // automatically trigger AI processing for newly inserted articles
        if(articlesToInsert.size() > 0) {
            System.enqueueJob(new ArticleAIProcessor());
        }

        System.debug('Inserted articles: ' + articlesToInsert.size());
        } else {
            System.debug('Error: ' + response.getStatusCode() + ' ' + response.getStatus());
        }
    }

 }