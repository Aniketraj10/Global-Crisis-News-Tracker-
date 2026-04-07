public class NewsAPIScheduler implements Schedulable {
    public void execute(SchedulableContext Context){
        
        for(Region__c region : [SELECT Name FROM Region__c]) {
        System.enqueueJob(new NewsApiCallout(region.Name));

        //changed from manual to dyanmic if user enters some different name 
    }
    }
}