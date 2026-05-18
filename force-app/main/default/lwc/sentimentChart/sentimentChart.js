import { LightningElement,api,wire } from 'lwc';
import getSentimentCounts from '@salesforce/apex/NewsFeedController.getSentimentCounts';

export default class SentimentChart extends LightningElement {

     @api region;
     positive = 0;
     negative = 0;
     neutral = 0;
     total = 0;

     @wire(getSentimentCounts, { region: '$region' })
     handleCounts({ data, error }) {
          if(data) {
               this.positive = 0;
               this.negative = 0;
               this.neutral = 0;
               this.total = 0;
               
               data.forEach(row => {
                    let count = row.total;
                    this.total += count;
                    if(row.Sentiment__c === 'Positive') this.positive = count;
                    if(row.Sentiment__c === 'Negative') this.negative = count;
                    if(row.Sentiment__c === 'Neutral') this.neutral = count;
               });
          }
     }


     get circumference() {
          return 2 * Math.PI * 80; // 502
     }

     get negativeStroke() {
          if(this.total === 0) return 0;
          return (this.negative / this.total) * this.circumference;
     }

     get neutralStroke() {
          if(this.total === 0) return 0;
          return (this.neutral / this.total) * this.circumference;
     }

     get positiveStroke() {
          if(this.total === 0) return 0;
          return (this.positive / this.total) * this.circumference;
     }

     get negativeOffset() {
          return 0;
     }

     get neutralOffset() {
           return -(this.negativeStroke);
     }

     get positiveOffset() {
           return -(this.negativeStroke + this.neutralStroke);
     }
}