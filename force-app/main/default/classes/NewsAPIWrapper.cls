public class NewsAPIWrapper { //using wrapper class insted of  JSON.deserialize() for better data and clean data visiuality
    
    // matches "status" in JSON response - tells us if API call was successful
    public String status;
    
    // matches "totalResults" in JSON - total number of articles available
    public Integer totalResults;
    
    // matches "articles" array in JSON - list of all article objects
    public List<Article> articles;
    
    // inner class - mirrors the structure of each article object in JSON
    public class Article {
        
        // matches "title" in JSON - headline of the news article
        public String title;
        
        // matches "description" in JSON - short summary of the article
        public String description;
        
        // matches "url" in JSON - link to the full article
        public String url;
        
        // matches "publishedAt" in JSON - when the article was published
        public String publishedAt;
        
        // matches "urlToImage" in JSON - thumbnail image of the article
        public String urlToImage;
        
        // matches "author" in JSON - who wrote the article
        public String author;
        
        // matches "source" object in JSON - nested object so separate inner class
        public Source source;
    }
    
    // inner class - mirrors the structure of the source object inside each article
    public class Source {
        
        // matches "id" in JSON - unique identifier of the news source
        public String id;
        
        // matches "name" in JSON - display name of the news source e.g. "BBC News"
        public String name;
    }
}

