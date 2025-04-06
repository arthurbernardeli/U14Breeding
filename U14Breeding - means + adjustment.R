library(shiny)
library(shinyjs)  # ✅ Enables JavaScript-based class toggling
library(openxlsx)
library(tidyverse)
library(doBy)
library(DT)
library(asreml)


# Define UI
ui <- fluidPage(
  useShinyjs(),  # ✅ Enables JavaScript
  tags$head(
    tags$link(rel = "stylesheet", type = "text/css", href = "styles.css")  # ✅ Load CSS file
  ),
  
  titlePanel(
    div(
      class = "app-title",
      HTML("Advanced Tests<br>Single-Year & Multi-Location Analyses<br>Phenotypic Selection")
    )
  ),
  
  tabsetPanel(
    id = "tabs",  # ✅ Track active tab
    
    # ✅ Tab 1: Data Upload & Processing
    tabPanel("Upload & Process - Averages", 
             sidebarLayout(
               sidebarPanel(
                 h4("Upload Field Book File"),
                 fileInput("datafile", "Upload Current Year Catalog (.xlsx)", accept = ".xlsx"),
                 
                 selectInput("trial", "Select Current Trial Code", choices = NULL),  # ✅ Dropdown for CODE selection
                 
                 actionButton("process", "Process Data"),  # ✅ Process button
                 hr(),
                 
                 # ✅ Standard download buttons
                 downloadButton("download_template", "Download Input Template (XLSX)"),
                 downloadButton("download_filtered_data", "Download Filtered Input Data (XLSX)"),
                 downloadButton("download_summary", "Download Results (XLSX)")
               ),
               
               mainPanel(
                 h4("")
               )
             )
    ),
    
    # ✅ Tab 2: Results (Results inside a gray box)
    tabPanel("Results",
             div(
               id = "results-box",  # ✅ Gray box around results
               DT::dataTableOutput("summaryTable")  # ✅ Displays processed data inside the box
             )
    )
  )
)

# Define Server
server <- function(input, output, session) {
  
  options(shiny.maxRequestSize = 100*1024^2)  # ✅ Allow large file uploads
  
  # ✅ Detect when "Results" tab is selected and change background
  observeEvent(input$tabs, {
    if (input$tabs == "Results") {
      runjs("document.body.classList.add('results-active');")  # ✅ Add gray background under results
    } else {
      runjs("document.body.classList.remove('results-active');")  # ✅ Remove it when switching back
    }
  })
  
  # ✅ Download Input Template File (Ensures XLSX format)
  output$download_template <- downloadHandler(
    filename = function() { "current.xlsx" },  
    content = function(file) {
      file.copy("www/current.xlsx", file, overwrite = TRUE)  
    },
    contentType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  )
  
  # ✅ Function to read Excel data
  read_clean_data <- function(file) {
    df <- read.xlsx(file)
    
    if ("CODE" %in% colnames(df)) df$CODE <- as.character(df$CODE)  
    if ("STRAIN" %in% colnames(df)) df$STRAIN <- as.character(df$STRAIN)  
    if ("ENV" %in% colnames(df)) df$ENV <- as.character(df$ENV)  
    
    return(df)
  }
  
  # ✅ Reactive expression to read the uploaded file
  catalog_reactive <- reactive({
    req(input$datafile)
    read_clean_data(input$datafile$datapath)
  })
  
  # ✅ Update dropdown with unique CODE values
  observeEvent(catalog_reactive(), {
    catalog <- catalog_reactive()
    
    if (!"CODE" %in% colnames(catalog)) {
      updateSelectInput(session, "trial", choices = c("No CODE available"))
      return()
    }
    
    unique_codes <- unique(na.omit(catalog$CODE))  
    updateSelectInput(session, "trial", choices = unique_codes, selected = unique_codes[1])
  })
  
  # ✅ Reactive expression for filtered input data
  filtered_input_data <- reactive({
    req(input$datafile, input$trial)
    catalog_reactive() %>% filter(CODE == input$trial) %>% droplevels()
  })
  
  # ✅ Download Filtered Input Data as .xlsx
  output$download_filtered_data <- downloadHandler(
    filename = function() { paste0("filtered_input_data_", input$trial, ".xlsx") },
    content = function(file) {
      req(filtered_input_data())
      write.xlsx(filtered_input_data(), file, overwrite = TRUE)
    },
    contentType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  )
  
  # ✅ Process data
  processed_data <- eventReactive(input$process, {
    req(filtered_input_data())
    data <- filtered_input_data()
    
    ##### ✅ Summary Statistics #####
    fun <- function(x) (mean(x, na.rm = TRUE))
    
    summary <- summaryBy(YIELD + MD + MD_DAP + LG + HT + PRO + OIL + Fibre + LINOLENIC + SAT_FAT +
                           Meal_Product_fiber + Meal_Product_Oil +
                           MEAL_PRO + MealProductYield + MillFeedUsed + EPV + EPVMealProduct +
                           EPVMillFeed + EPVOil + COY ~ STRAIN, data = data, FUN = fun)
    
    summary$CODE <- input$trial  
    
    colnames(summary) <- c('STRAIN', 'YIELD_AVG' , 'MD' , 'MD_DAP', 'LG' , 'HT', 'PRO', 'OIL', 'Fibre', 'LINOLENIC', 'SAT_FAT', 'Meal_Product_fiber', 'Meal_Product_Oil',
                           'MEAL_PRO', 'MealProductYield', 'MillFeedUsed', 'EPV', 'EPVMealProduct',
                           'EPVMillFeed', 'EPVOil', 'COY', 'CODE')
    

    summary$YIELD_AVG <- round(summary$YIELD_AVG,2)
    summary$MD <- round(summary$MD,0)
    summary$MD_DAP <- round(summary$MD_DAP,0)
    summary$LG <- round(summary$LG,0)
    summary$HT <- round(summary$HT,0)
    summary$PRO <- round(summary$PRO,1)
    summary$OIL <- round(summary$OIL,1)
    summary$Fibre <- round(summary$Fibre,1)
    summary$LINOLENIC <- round(summary$LINOLENIC,1)
    summary$SAT_FAT <- round(summary$SAT_FAT,1)
    summary$Meal_Product_fiber <- round(summary$Meal_Product_fiber,1)
    summary$Meal_Product_Oil <- round(summary$Meal_Product_Oil,1)
    summary$MEAL_PRO <- round(summary$MEAL_PRO,1)
    summary$MealProductYield <- round(summary$MealProductYield,1)
    summary$MillFeedUsed <- round(summary$MillFeedUsed,1)
    summary$EPV <- round(summary$EPV,1)
    summary$EPVMealProduct <- round(summary$EPVMealProduct,1)
    summary$EPVMillFeed <- round(summary$EPVMillFeed,1)
    summary$EPVOil <- round(summary$EPVOil,1)
    summary$COY <- round(summary$COY,1)
    
    summary$SumPO <- summary$PRO + summary$OIL
    summary$SumPO <- round(summary$SumPO,1)
    
    summary <- summary %>% select(CODE, STRAIN, YIELD_AVG, MD, MD_DAP, LG, HT, PRO, OIL, SumPO, MEAL_PRO, MealProductYield, COY, EPVOil, Fibre)
    
    final1 <- summary  
    
    ##### ✅ Min & Max Summary #####
    fun2 <- function(x) c(Min = round(min(x, na.rm = TRUE), 2), Max = round(max(x, na.rm = TRUE), 2))
    
    summary2 <- summaryBy(YIELD ~ STRAIN, data = data, FUN = fun2)
    
    summary2$CODE <- input$trial  
    summary2 <- summary2 %>% select(CODE, STRAIN, YIELD.Min, YIELD.Max)  
    colnames(summary2) <- c("CODE", "STRAIN", "YIELD_MIN", "YIELD_MAX")
    summary2$YIELD_MIN <- round(summary2$YIELD_MIN,2)
    summary2$YIELD_MAX <- round(summary2$YIELD_MAX,2)
    
    final2 <- summary2  
    
    ##### ✅ Merge Data #####
    merged_final <- final1 %>% left_join(final2, by = c("CODE", "STRAIN"))
    merged_final <- merged_final %>% select(CODE, STRAIN, YIELD_AVG, YIELD_MIN, YIELD_MAX,MD, MD_DAP, LG, HT, PRO, OIL, SumPO, MEAL_PRO, MealProductYield, COY, EPVOil, Fibre) 
    
    ##### ✅ Experimental Design Adjustment#####

phen <- data
phen <- phen %>%
  filter(DQUAL == "Good")

phen <- phen %>%
  select(STRAIN, TESTNO, ENV, REP, YIELD,CODE)

phen$STRAIN<-factor(phen$STRAIN)
phen$TESTNO<-factor(phen$TESTNO)
phen$REP<-factor(phen$REP)
phen$ENV<-factor(phen$ENV)
phen$CODE<-factor(phen$CODE)
phen$YIELD<-as.numeric(phen$YIELD)

model <- asreml(fixed = YIELD ~ STRAIN + ENV, 
                random = ~ STRAIN*ENV + ENV:(TESTNO:REP), 
                workspace = 128e06, maxiter = 100,
                na.action = na.method(y = "omit", x = "omit"),
                data = phen)

predM <- predict(model, "STRAIN",pworkspace=300e06,vcov=TRUE)
pred<-predM$pvals[,1:3]

pred <- pred %>%
  rename(STRAIN = STRAIN, 
         Estimate = predicted.value, 
         StdErr = std.error)

pred$Estimate<-round(pred$Estimate,2)
pred$StdErr<-round(pred$StdErr,2)
pred$CODE<-levels(phen$CODE)

pred <- pred %>%
  select(CODE, STRAIN, Estimate, StdErr)

adjusted<-pred

###

merged_adjusted_final <- adjusted%>% left_join(merged_final, by = c("CODE", "STRAIN"))
merged_adjusted_final <- merged_adjusted_final %>% select(CODE, STRAIN, Estimate, StdErr, YIELD_AVG, YIELD_MIN, YIELD_MAX,MD, MD_DAP, LG, HT, PRO, OIL, SumPO, MEAL_PRO, MealProductYield, COY, EPVOil, Fibre)

###

REP <- phen %>%
  count(STRAIN)

REP <- REP %>%
  rename(STRAIN = STRAIN, REPS = n)

###

merged_adjusted_final$YPD<-merged_adjusted_final$Estimate/merged_adjusted_final$MD_DAP
merged_adjusted_final$YPD<-round(merged_adjusted_final$YPD,2)
merged_rep<- merged_adjusted_final %>% left_join(REP, by = "STRAIN")

###

merged_rep <- merged_rep %>% select(CODE, STRAIN, Estimate, StdErr, MD, MD_DAP, REPS, LG, HT, YIELD_AVG, YIELD_MIN, YIELD_MAX, YPD, PRO, OIL, SumPO, MEAL_PRO, MealProductYield, COY, EPVOil, Fibre)

merged_rep <- merged_rep %>%
  arrange(desc(Estimate))

###

save<-merged_rep
return(save)    

###

  })
  
  # ✅ Download Processed Summary Data as .xlsx
  output$download_summary <- downloadHandler(
    filename = function() { paste0("summary_data_", input$trial, ".xlsx") },
    content = function(file) {
      req(processed_data())
      write.xlsx(processed_data(), file, overwrite = TRUE)
    },
    contentType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  )
  
  # ✅ Display Processed Data
  output$summaryTable <- DT::renderDataTable({
    req(processed_data())  
    datatable(processed_data(), options = list(scrollX = TRUE, pageLength = 10))
  })
}

shinyApp(ui = ui, server = server)
