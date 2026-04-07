import { LightningElement,api,wire } from 'lwc';
import getEvents from '@salesforce/apex/NewsFeedController.getEvents';

export default class CrisisTimeline extends LightningElement {
     @api regionName = ''
     events = []

     @wire(getEvents,{regionName : '$regionName'})
     eventsData({data,error}) {
          if(data){
               this.events = data.map(event => ({
                    ...event,
                    severityClass: event.Severity__c === 'High' ? 'timeline-dot dot-high' :
                                   event.Severity__c === 'Medium' ? 'timeline-dot dot-medium' : 
                                   'timeline-dot dot-low'
               }));
          }
          if(error){
               console.log(error);
               
          }

          
     }

     

}