
# Create 4x small multiples for each of the sub-IRs -----------------------
# 20 June 2016
# Laura Hughes, lhughes@usaid.gov

# ui code -----------------------------------------------------------------

indivResultUI = function(id){
  ns <- NS(id)
  
  tagList(
    fluidRow(htmlOutput(ns('title'))),
    fluidRow(leafletOutput(ns('resultsMap')))
    
  )
}


# server code -------------------------------------------------------------

indivResult = function(input, output, session, df, selResult, 
                       ips, results, mechanisms){
  
  # filter the data to the District for indicated result -----------------------------------------
  
  filter_result = reactive({
    basic_filtered = df %>% 
      # -- Filter out mechanisms based on user input --
      filter( 
        mechanism %in% mechanisms(),
        result %in% results(),
        subIR_ID %like% selResult,
        IP %in% ips()) 
    
    result_name = basic_filtered %>% 
      group_by(Province, District, output) %>% 
      summarise(ips = paste('&emsp; &bull;', shortName, collapse = ' <br> ')) %>% 
      ungroup() %>% 
      group_by(Province, District) %>% 
      summarise(ips = paste('<strong>', output, '</strong> <br>', ips, collapse = ' <br> '))
    
    ct_byDist = basic_filtered %>%
      # -- Group by District and count --
      group_by(Province, District) %>% 
      summarise(num = n())
    
    full_join(ct_byDist, result_name, by = c('Province', 'District'))
  })
  
  
  
  # Leaflet map ---------------------------------------------------
  output$resultsMap = renderLeaflet({
    
    filteredDF = filter_result()
    
    rw_adm2@data = full_join(rw_adm2@data, filteredDF, by = 'District')
    
    # -- Pull out the centroids --
    rw_centroids = data.frame(coordinates(rw_adm2)) %>%
      rename(Lon = X1, Lat = X2)
    
    rw_centroids = cbind(rw_centroids,
                         District = rw_adm2@data$District)
    
    rw_centroids = left_join(filteredDF, rw_centroids, by = 'District')
    
    
    # -- Info popup box --
    info_popup <- paste0("<strong>District: </strong>",
                         rw_adm2$District,
                         "<br><strong>results: </strong> <br>",
                         rw_adm2$ips)
    
    info_popup_circles <- paste0("<strong>District: </strong>",
                                 rw_centroids$District,
                                 "<br><strong>mechanisms: </strong> <br>",
                                 rw_centroids$ips)
    
    # -- leaflet map --
    leaflet(data = rw_adm2) %>%
      addProviderTiles("Esri.WorldGrayCanvas",
                       options = tileOptions(minZoom = 8, maxZoom  = 11)) %>%
      setMaxBounds(minLon, minLat, maxLon, maxLat) %>% 
      addPolygons(fillColor = ~contPal(num),
                  fillOpacity = 0.6,
                  color = grey90K,
                  weight = 1,
                  popup = info_popup) %>% 
      addLegend("bottomright", pal = contPal, values = ~num,
                title = "# outputs",
                opacity = 1)
  })
  
  output$title = renderPrint({
    h3(subIRs[subIRs %like% selResult])
  })
  # -- fin --
}






