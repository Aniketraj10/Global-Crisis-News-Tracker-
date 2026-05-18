public with sharing class SchedulerManager {
    public static void reschedule(String cronExpression) {
        // Step 1: abort existing job

        for(CronTrigger ct : [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = 'News Fetch Job']) {
            System.abortJob(ct.Id);
        }
        // Step 2: schedule new job with cronExpression
        System.schedule('News Fetch Job', cronExpression, new NewsAPIScheduler());
    }
}