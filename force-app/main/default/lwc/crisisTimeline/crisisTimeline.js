import { LightningElement, api, wire } from 'lwc';
import getEvents from '@salesforce/apex/NewsFeedController.getEvents';

export default class CrisisTimeline extends LightningElement {
    
    // @api makes regionName accessible from parent component (newsFeed)
    // parent passes selected region down via region-name={region}
    @api regionName = ''
    
    events = [] // stores processed events for display in HTML

    // @wire automatically calls getEvents when regionName changes
    // '$regionName' — $ makes it reactive, re-fires wire when value changes
    @wire(getEvents, { regionName: '$regionName' })
    eventsData({ data, error }) {
        if(data) {
            this.events = data.map(event => ({
                // ...event spreads all original Apex fields onto the new object
                // so we keep Title, Date, Severity etc without listing each one
                ...event,

                // add a computed CSS class based on Severity__c value
                // Apex doesn't know about CSS — we map severity to class name here
                // HTML then uses {event.severityClass} to apply the right color
                severityClass: event.Severity__c === 'High' ? 'timeline-dot dot-high' :
                               event.Severity__c === 'Medium' ? 'timeline-dot dot-medium' : 
                               'timeline-dot dot-low'
            }));
        }
        if(error) {
            console.log(error);
        }
    }
}