import { LightningElement, wire } from 'lwc';
import getNews from '@salesforce/apex/NewsFeedController.getNews';
import getRegions from '@salesforce/apex/NewsFeedController.getRegions';

export default class NewsFeed extends LightningElement {

    region = '';
    articles = [];
    errorMessage;
    regionOptions = [];

    handleRegionChange(event){
        this.region = event.target.value;
    }

    @wire(getNews, { region: '$region' })
    handleNews({ data, error }) {
        if(data) {
            this.articles = data;
        } else if(error) {
            this.errorMessage = error;
        }
    }

    @wire(getRegions)
    handleRegions({ data, error }) {
        if(data) {
            this.regionOptions = data.map(region => ({
                label: region.Name,//what the user sees in the dropdown
                value: region.Name,// what gets stored in this.region when selected
                isSelected: region.Name === data[0].Name
            }));
            //set default region to first Option
            if(this.regionOptions.length > 0){
                this.region = this.regionOptions[0].value
            }
        }if(error){
            console.log(error);
            
        }
    }

    get formattedArticles() {
        // check if articles array has data
        if(this.articles.length > 0) {
            return this.articles.map(article => {
                return {
                    ...article,
                    formattedDate: new Date(article.Published_At__c).toLocaleDateString('en-US', {
                        year: 'numeric',
                        month: 'long',
                        day: 'numeric'
                    })
                };
            });
        }
        return [];
    }
}