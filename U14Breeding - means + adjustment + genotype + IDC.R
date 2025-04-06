library(shiny)
library(shinyjs)  # ✅ Enables JavaScript-based class toggling
library(openxlsx)
library(tidyverse)
library(doBy)
library(DT)
library(asreml)

# Define UI
ui <- fluidPage(
  useShinyjs(),  # Enables JavaScript
  tags$head(
    tags$link(rel = "stylesheet", type = "text/css", href = "styles.css"),  # Load CSS file
    # Add custom styles to remove unwanted borders
    tags$style(HTML("
      .tab-content {
        border-top: none !important;
        box-shadow: none !important;
      }
      .nav-tabs {
        border-bottom: none !important;
      }
      .tab-pane {
        border-top: none !important;
      }
      .navbar {
        border-bottom: none !important;
      }
    "))
  ),
  
  # Application title with line breaks
  titlePanel(
    div(
      class = "app-title",
      HTML("Advanced Tests<br>Single-Year & Multi-Location Analyses<br>Phenotypic Selection")
    )
  ),
  
  # Subtitle panel for inputs
  div(
    class = "subtitle-panel",
    style = "text-align: center; font-size: 18px; font-weight: bold; margin-bottom: 20px; color: white;",
    HTML("Inputs: Current Year Master Catalog (Phenotypes & Genotypes) and IDC Catalog")
  ),
  
  # Tabset panel
  tabsetPanel(
    id = "tabs",  # Track active tab
    
    # Tab 1: Data Upload & Processing
    tabPanel("Upload & Process", 
             sidebarLayout(
               sidebarPanel(
                 fileInput("datafile", "Upload Current Year Master Catalog (.xlsx)", accept = ".xlsx"),
                 fileInput("idcfile", "Upload Current Year IDC Catalog (.xlsx)", accept = ".xlsx"),  # Added second file input
                 selectInput("trial", "Select Current Trial Code", choices = NULL),  # Dropdown for CODE selection
                 actionButton("process", "Run Analyses"),  # Process button
                 hr(),
                 # Standard download buttons
                 downloadButton("download_template", "Download Master Catalog Input Template (XLSX)"),
                 downloadButton("download_idc_template", "Download IDC Catalog Input Template (XLSX)"),
                 downloadButton("download_filtered_data", "Download Filtered Master Catalog (XLSX)"),
                 downloadButton("download_filtered_idc", "Download Filtered IDC Catalog (XLSX)"),
                 downloadButton("download_summary", "Download Results (XLSX)")
               ),
               mainPanel(
                 h4("")
               )
             )
    ),
    
    # Tab 2: Results
    tabPanel("Results",
             div(
               id = "results-box",  # Gray box around results
               DT::dataTableOutput("summaryTable")  # Displays processed data inside the box
             )
    ),
    
    # Tab 3: Instructions
    tabPanel("Instructions",
             div(
               id = "instructions-box",  # Gray box around instructions
               style = "padding: 20px; max-width: 900px; margin: auto; text-align: justify;",
               h3("How to Use This App"),
               p("This application allows users to analyze phenotypic selection data by uploading Master Catalog and IDC Catalog files."),
               h4("Steps to Follow:"),
               tags$ol(
                 tags$li("Upload the 'Current Year Master Catalog' file (.xlsx)."),
                 tags$li("Upload the 'Current Year IDC Catalog' file (.xlsx)."),
                 tags$li("Select the trial you want to analyze."),
                 tags$li("Click 'Run Analyses' to process the data."),
                 tags$li("Download the filtered datasets and results from the available buttons.")
               ),
               h4("File Format Requirements:"),
               p("Ensure that your Excel files (.xlsx) are formatted correctly before uploading. The datasets should contain the required columns, including:"),
               tags$ul(
                 tags$li("CODE - Unique identifier for each trial"),
                 tags$li("STRAIN - Identifier for different plant strains"),
                 tags$li("ENV - Environmental conditions"),
                 tags$li("IDC_SCORE - Iron deficiency chlorosis score (for IDC Catalog)"),
                 tags$li("NOTES - Additional observations")
               ),
               h4("Contact & Support:"),
               p("For any issues, contact the developers at:"),
               p(HTML("<b>Arthur Bernardeli & George Graef</b><br>University of Nebraska-Lincoln"))
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
  
  output$download_idc_template <- downloadHandler(
    filename = function() { "idc.xlsx" },  
    content = function(file) {
      file.copy("www/idc.xlsx", file, overwrite = TRUE)  
    },
    contentType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  )
  
  # ✅ Function to read Excel data
  read_clean_data <- function(file) {
    df <- read.xlsx(file)
    
    if ("CODE" %in% colnames(df)) df$CODE <- as.character(df$CODE)  
    if ("STRAIN" %in% colnames(df)) df$STRAIN <- as.character(df$STRAIN)  
    if ("ENV" %in% colnames(df)) df$ENV <- as.character(df$ENV)  
    if ("YEAR" %in% colnames(df)) df$YEAR <- as.character(df$YEAR)  
    
    return(df)
  }
  
  # ✅ Reactive expression to read the uploaded file
  catalog_reactive <- reactive({
    req(input$datafile)
    read_clean_data(input$datafile$datapath)
  })
  
  # ✅ Function to read and clean IDC data (Customized)
  read_clean_idc <- function(file) {
    df <- read.xlsx(file)
    
    if ("CODE" %in% colnames(df)) df$CODE <- as.character(df$CODE)  
    if ("IDC_SCORE" %in% colnames(df)) df$IDC_SCORE <- as.numeric(df$IDC_SCORE)  # Example: Convert a score column
    if ("NOTES" %in% colnames(df)) df$NOTES <- as.character(df$NOTES)  
    
    return(df)
  }
  
  # ✅ Read "idc" file using the custom function
  idc_reactive <- reactive({
    req(input$idcfile)
    read_clean_idc(input$idcfile$datapath)
  })
  
  # ✅ Update dropdown with unique CODE values from both files
  observeEvent({ list(catalog_reactive(), idc_reactive()) }, {
    catalog <- catalog_reactive()
    idc <- idc_reactive()
    
    # Check if "CODE" column exists in either dataset
    catalog_codes <- if ("CODE" %in% colnames(catalog)) unique(na.omit(catalog$CODE)) else character(0)
    idc_codes <- if ("CODE" %in% colnames(idc)) unique(na.omit(idc$CODE)) else character(0)
    
    # Combine unique CODEs from both datasets
    all_codes <- unique(c(catalog_codes, idc_codes))
    
    if (length(all_codes) == 0) {
      updateSelectInput(session, "trial", choices = c("No CODE available"))
    } else {
      updateSelectInput(session, "trial", choices = all_codes, selected = all_codes[1])
    }
  })
  
  # ✅ Reactive expression for filtered 'current' data
  filtered_input_data <- reactive({
    req(input$datafile, input$trial)
    catalog_reactive() %>% filter(CODE == input$trial) %>% droplevels()
  })
  
  # ✅ Reactive expression for filtered IDC data
  filtered_idc_data <- reactive({
    req(input$idcfile, input$trial)
    idc_reactive() %>% filter(CODE == input$trial) %>% droplevels()
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
  
  # ✅ Download Filtered IDC Data as .xlsx
  output$download_filtered_idc <- downloadHandler(
    filename = function() { paste0("filtered_idc_data_", input$trial, ".xlsx") },
    content = function(file) {
      req(filtered_idc_data())
      write.xlsx(filtered_idc_data(), file, overwrite = TRUE)
    },
    contentType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  )
  
  # ✅ Process "current" data when the button is clicked
  processed_data <- eventReactive(input$process, {
    req(filtered_input_data())  # Ensure data exists
    data <- filtered_input_data()  # ✅ Keep "data" for current dataset
    
    # Add your data processing functions here for the "current" dataset
    # Example: data <- some_analysis_function(data)
    
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
      select(YEAR,STRAIN, TESTNO, ENV, REP, YIELD,CODE)
    
    phen$STRAIN<-factor(phen$STRAIN)
    phen$TESTNO<-factor(phen$TESTNO)
    phen$REP<-factor(phen$REP)
    phen$ENV<-factor(phen$ENV)
    phen$CODE<-factor(phen$CODE)
    phen$YEAR<-factor(phen$YEAR)
    phen$YIELD<-as.numeric(phen$YIELD)
    
    model <- asreml(fixed = YIELD ~ 1, 
                    random = ~ STRAIN + ENV + STRAIN*ENV + ENV:(TESTNO:REP), 
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
    
    merged_rep <- merged_rep %>% select(CODE, STRAIN, Estimate, StdErr, MD, MD_DAP, REPS, LG, HT, YIELD_AVG, YIELD_MIN, YIELD_MAX, YPD, PRO, OIL, SumPO, MEAL_PRO, MealProductYield, COY, EPVOil, Fibre)
    
    ##### ✅ Incorporating  test summary, pedigree, and marker information #####
    
    geno<-data
    geno<-geno%>%select(CODE,STRAIN,PREV_CODE,INFO,FEMALE,MALE,POP,CROSS_ID,FEMALE_TRAITS,MALE_TRAITS,
                        Rhg1_LGC,Rhg2_LGC,Rhg4_LGC,cqSCN_006_LGC,cqSCN_007_LGC,JOB_LGC,JOB,Rhg1_7E7D,
                        Rhg1_7FC8,Rhg4,RKI,Rps1a,Rps1c,Rps1d,Rps1k,Rps2,Rps3a,Rps6,BSR,Rcs3,Rdc3,Dt1,
                        Dt2,E1_NULL,E1,E2,E3,E4,FT1,J4,W1,PB_7N80,PB_HC,I,R,PC_7BTB,PC_E31,IDC_QTL,
                        IDC_75Y5,IDC_753B,ALS1,ALS2,Cda1,Chloride,PPO)
    
    geno <- geno %>%
      distinct(STRAIN, CODE, .keep_all = TRUE)
    
    merged_geno <- merged_rep %>% left_join(geno, by = c("CODE", "STRAIN"))
    
    merged_geno <- merged_geno %>% select(CODE, STRAIN, Estimate, StdErr, MD, MD_DAP, REPS, LG, HT, YIELD_AVG, 
                                          YIELD_MIN, YIELD_MAX, YPD, PRO, OIL, SumPO, MEAL_PRO, MealProductYield, 
                                          COY, EPVOil, Fibre,PREV_CODE,INFO,FEMALE,MALE,POP,CROSS_ID,FEMALE_TRAITS,
                                          MALE_TRAITS,Rhg1_LGC,Rhg2_LGC,Rhg4_LGC,cqSCN_006_LGC,cqSCN_007_LGC,JOB_LGC,
                                          JOB,Rhg1_7E7D,Rhg1_7FC8,Rhg4,RKI,Rps1a,Rps1c,Rps1d,Rps1k,Rps2,Rps3a,Rps6,
                                          BSR,Rcs3,Rdc3,Dt1, Dt2,E1_NULL,E1,E2,E3,E4,FT1,J4,W1,PB_7N80,PB_HC,I,R,
                                          PC_7BTB,PC_E31,IDC_QTL,IDC_75Y5,IDC_753B,ALS1,ALS2,Cda1,Chloride,PPO)
    merged_geno <- merged_geno %>%
      arrange(desc(Estimate))
    
    ###
    
    pheno_geno<-merged_geno
    return(pheno_geno)    
    
  })

  # ✅ Process "IDC" data when the button is clicked
  #processed_idc_data <- eventReactive(input$process, {
  #  req(filtered_idc_data())  # Ensure data exists
  #  idcdata <- filtered_idc_data()  # ✅ Rename to "idcdata" for IDC dataset
  #  
  #  # Add your data processing functions here for the IDC dataset
  #  # Example: idcdata <- idc_analysis_function(idcdata)
  #  
  #  return(idcdata)
  #  })
  
  # ✅ Download Processed Summary Data as .xlsx
  
  
  # ✅ Download Processed Summary Data as .xlsx
  year<-as.numeric(format(Sys.Date(), "%Y"))-1
  prev<-as.numeric(format(Sys.Date(), "%Y"))-2
  
  output$download_summary <- downloadHandler(
    filename = function() { paste0(year," Single-Year & Multi-Loc ", input$trial, ".xlsx") },
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


