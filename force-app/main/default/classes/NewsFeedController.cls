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
}