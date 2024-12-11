library(shiny)
library(tidyverse)
library(tidymodels)
library(bslib)
library(xgboost)
library(shinyWidgets)

# Load the saved model and recipe
final_model <- readRDS("data/final_model.rds")
data_prep <- readRDS("data/data_prep.rds")

# Theme setup
my_theme <- bs_theme(
  version = 5,
  bootswatch = "flatly",
  primary = "#2C3E50",
  "navbar-bg" = "#2C3E50"
)

ui <- page_sidebar(
  title = div(
    tags$span("Customer Churn Prediction", style = "font-size: 24px;"),
    tags$span(" | ", style = "color: #666;"),
    tags$span("by Leykun Getaneh", style = "font-style: italic;")
  ),
  theme = my_theme,
  
  # Sidebar with organized sections
  sidebar = sidebar(
    width = 300,
    title = "Input Parameters",
    
    # Demographics section
    accordion(
      accordion_panel(
        "Demographics",
        icon = icon("user"),
        selectInput("gender", "Gender", choices = c("Female", "Male")),
        selectInput("senior_citizen", "Senior Citizen", choices = c("No" = "0", "Yes" = "1")),
        selectInput("partner", "Partner", choices = c("Yes", "No")),
        selectInput("dependents", "Dependents", choices = c("Yes", "No"))
      ),
      
      # Services section
      accordion_panel(
        "Services",
        icon = icon("tools"),
        selectInput("phone_service", "Phone Service", choices = c("Yes", "No")),
        selectInput("multiple_lines", "Multiple Lines", 
                    choices = c("Yes", "No", "No phone service")),
        selectInput("internet_service", "Internet Service", 
                    choices = c("DSL", "Fiber optic", "No")),
        selectInput("online_security", "Online Security", 
                    choices = c("Yes", "No", "No internet service")),
        selectInput("online_backup", "Online Backup", 
                    choices = c("Yes", "No", "No internet service")),
        selectInput("device_protection", "Device Protection", 
                    choices = c("Yes", "No", "No internet service")),
        selectInput("tech_support", "Tech Support", 
                    choices = c("Yes", "No", "No internet service")),
        selectInput("streaming_tv", "Streaming TV", 
                    choices = c("Yes", "No", "No internet service")),
        selectInput("streaming_movies", "Streaming Movies", 
                    choices = c("Yes", "No", "No internet service"))
      ),
      
      # Contract & Billing section
      accordion_panel(
        "Contract & Billing",
        icon = icon("file-invoice-dollar"),
        selectInput("contract", "Contract Type", 
                    choices = c("Month-to-month", "One year", "Two year")),
        selectInput("paperless_billing", "Paperless Billing", 
                    choices = c("Yes", "No")),
        selectInput("payment_method", "Payment Method", 
                    choices = c("Electronic check", "Mailed check", 
                                "Bank transfer (automatic)", 
                                "Credit card (automatic)")),
        numericInput("monthly_charges", "Monthly Charges ($)", 
                     value = 50, min = 0),
        numericInput("total_charges", "Total Charges ($)", 
                     value = 1000, min = 0),
        numericInput("tenure", "Tenure (months)", value = 12, min = 0)
      )
    )
  ),
  
  # Main panel content
  # Description card
  card(
    card_header(
      class = "bg-primary text-white",
      "Customer Churn Prediction Tool"
    ),
    p("This tool uses machine learning to predict customer churn probability based on various customer attributes and behaviors."),
    p("Enter customer information in the sidebar to get predictions. The model uses XGBoost algorithm trained on historical customer data.")
  ),
  
  # Prediction boxes with equal width and height
  layout_columns(
    col_widths = c(6, 6),
    heights_equal = "row",
    value_box(
      title = "Churn Probability",
      value = textOutput("churn_prob"),
      showcase = icon("percentage"),
      theme = "warning",
      full_screen = TRUE,
      class = "shadow-sm h-100"
    ),
    uiOutput("prediction_box")
  ),
  
  # Risk factors card
  card(
    card_header(
      class = "bg-primary text-white",
      "Risk Factors Analysis"
    ),
    textOutput("risk_factors")
  )
)

server <- function(input, output, session) {
  
  # Create reactive for new customer data
  new_customer <- reactive({
    tibble(
      gender = input$gender,
      senior_citizen = as.numeric(input$senior_citizen),
      partner = input$partner,
      dependents = input$dependents,
      tenure = input$tenure,
      phone_service = input$phone_service,
      multiple_lines = input$multiple_lines,
      internet_service = input$internet_service,
      online_security = input$online_security,
      online_backup = input$online_backup,
      device_protection = input$device_protection,
      tech_support = input$tech_support,
      streaming_tv = input$streaming_tv,
      streaming_movies = input$streaming_movies,
      contract = input$contract,
      paperless_billing = input$paperless_billing,
      payment_method = input$payment_method,
      monthly_charges = input$monthly_charges,
      total_charges = input$total_charges
    ) %>% 
      # Add some dummy values to get the algorithm to work
      mutate(
        customer_id = "1"
      )
    
  })
  
  # Make prediction
  pred_prob <- reactive({
    pred <- predict(final_model, new_customer(), type = "prob")
    return(pred$.pred_1)
  })
  
  # Display results
  output$churn_prob <- renderText({
    sprintf("%.1f%%", pred_prob() * 100)
  })
  
  output$prediction_box <- renderUI({
    prob <- pred_prob()
    theme_color <- if(prob >= 0.5) "danger" else "success"
    prediction_text <- if(prob >= 0.5) "Likely to Churn" else "Likely to Stay"
    
    value_box(
      title = "Predicted Outcome",
      value = prediction_text,
      showcase = icon("user-check"),
      theme = theme_color,
      full_screen = TRUE,
      class = "shadow-sm h-100"
    )
  })
  
  # Risk factors analysis
  output$risk_factors <- renderText({
    prob <- pred_prob()
    
    risk_factors <- c()
    
    if(input$contract == "Month-to-month") {
      risk_factors <- c(risk_factors, "Month-to-month contract")
    }
    if(input$tenure < 12) {
      risk_factors <- c(risk_factors, "Low tenure")
    }
    if(input$internet_service == "Fiber optic" && 
       input$tech_support == "No") {
      risk_factors <- c(risk_factors, "Fiber service without tech support")
    }
    if(input$payment_method == "Electronic check") {
      risk_factors <- c(risk_factors, "Electronic check payment method")
    }
    
    if(length(risk_factors) > 0) {
      paste("Key risk factors identified:", paste(risk_factors, collapse = ", "))
    } else {
      "No significant risk factors identified"
    }
  })
}

shinyApp(ui, server)
