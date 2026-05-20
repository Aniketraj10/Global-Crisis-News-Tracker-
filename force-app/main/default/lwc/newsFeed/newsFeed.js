import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getNews from '@salesforce/apex/NewsFeedController.getNews';
import getRegions from '@salesforce/apex/NewsFeedController.getRegions';

export default class NewsFeed extends LightningElement {

    region = '';        // currently selected region — reactive, drives wire calls
    articles = [];      // raw articles from Apex
    errorMessage;       // stores error message if wire fails
    regionOptions = []; // formatted options for the select dropdown
    showModal = false;  // controls add region modal visibility

    // stores the full wire result so refreshApex can re-trigger getRegions
    wiredRegionsResult;

    // fires when user selects a different region from dropdown
    // updates this.region which reactively triggers getNews wire
    handleRegionChange(event){
        this.region = event.target.value;
    }

    // opens the add region modal
    handleAddRegion() {
        this.showModal = true;
    }

    // closes the modal — triggered by 'close' CustomEvent from addRegionModal
    handleModalClose() {
        this.showModal = false;
    }

    // fired when region is successfully added in the modal
    // closes modal and refreshes region dropdown to show new region
    handleRegionAdded() {
        this.showModal = false;
        refreshApex(this.wiredRegionsResult); // re-calls getRegions Apex method
    }

    // wire handler for news articles — re-fires when this.region changes
    @wire(getNews, { region: '$region' })
    handleNews({ data, error }) {
        if(data) {
            this.articles = data;
        } else if(error) {
            this.errorMessage = error;
        }
    }

    // wire handler for regions — stores full result for refreshApex
    @wire(getRegions)
    handleRegions(result) {
        // store entire wire result — needed for refreshApex to work
        this.wiredRegionsResult = result;
        const { data, error } = result;
        if(data) {
            // map Region__c records to dropdown option format
            this.regionOptions = data.map(region => ({
                label: region.Name,     // what user sees in dropdown
                value: region.Name,     // what gets stored in this.region
                isSelected: region.Name === data[0].Name // first region selected by default
            }));
            // set default region — triggers getNews wire automatically
            if(this.regionOptions.length > 0){
                this.region = this.regionOptions[0].value;
            }
        }
        if(error){
            console.log(error);
        }
    }

    // getter that formats articles for display
    // adds formattedDate property to each article
    get formattedArticles() {
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