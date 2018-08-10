library(leaflet)
library(rgdal)
library(dplyr)
library(stats)
library(ggmap)
library(ggplot2)
library(sp)
library(htmltools)

### Get Map boundaries
boundaries_da <- readOGR("./Winnipeg_DA_Boundaries/Winnipeg_DA_Boundaries.shp")
centroids <- read.csv("./centroids.csv")

#### Top 10 busiest intersections ###########
top10_nodes <- read.csv("./top10_nodes.csv")
map1 <- leaflet(data = top10_nodes) %>%
  addTiles() %>%  # Add default OpenStreetMap map tiles
  addCircles(~lon, ~lat, weight = 1,
             radius = ~sqrt(top10_nodes$Total)*5,
             label = ~map_id,
             labelOptions = labelOptions(noHide = T, direction = "center",textOnly = TRUE,
                                         style = list(
                                           "color" = "blue",
                                           "font-family" = "serif",
                                           "font-style" = "italic",
                                           "box-shadow" = "3px 3px rgba(0,0,0,0.0)",
                                           "font-size" = "12px",
                                           "border-color" = "rgba(0,0,0,0.5)"
                                         ))
  )
# Print the map
map1




#### Plot connections beween DAs and Intersections


DAs_node <- read.csv("./DAs/Node_name[1].csv")

# merge two data frames by ID
total <- merge(centroids,DAs_node,by="DA")

data_df <- data.frame(DA = total$DA,
                      count = total$count,
                      FromLat = total$lat.x,
                      FromLong = total$lon.x,
                      ToLat = total$lat.y,
                      ToLong = total$lon.y,
                      stringsAsFactors = FALSE)

## sort dataframe according to count

data_df<-data_df[order(data_df$count),] 
data<-tail(data_df)


map2 = leaflet(data) %>% addTiles()
map2 <-map2 %>% addCircleMarkers(~ToLong,~ToLat,label="G",
                                 labelOptions = labelOptions(noHide = T, 
                                                            direction = "center",textOnly = TRUE,
                                                            style = list(
                                                                        "color" = "white",
                                                                        "font-family" = "serif",
                                                                        "font-style" = "italic",
                                                                        "box-shadow" = "3px 3px rgba(0,0,0,0.0)",
                                                                        "font-size" = "20px",
                                                                        "border-color" = "rgba(0,0,0,0.5)"
                                                            )))
map2 <- map2 %>% addCircleMarkers(~FromLong,~FromLat, label=data$DA,
                                  labelOptions = labelOptions(noHide = T, 
                                                              direction = "center",textOnly = TRUE,
                                                              style = list(
                                                                "color" = "black",
                                                                "font-family" = "serif",
                                                                "font-style" = "italic",
                                                                "box-shadow" = "3px 3px rgba(0,0,0,0.0)",
                                                                "font-size" = "15px",
                                                                "border-color" = "rgba(0,0,0,0.5)"
                                                              )))
for(i in 1:nrow(data)){
  
  map2 <- addPolylines(map2,weight = data$count[i]/20, lat = as.numeric(data[i, c(3, 5)]), 
                       lng = as.numeric(data[i, c(4, 6)]))
}
map2
