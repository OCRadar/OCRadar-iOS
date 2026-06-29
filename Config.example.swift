import Foundation

// Copy this file to `Config.swift` and fill in your own values.
// `Config.swift` is gitignored so your real keys never get committed.
//
// Get these from the Azure Custom Vision portal:
//   Prediction resource -> Keys & Endpoint, and your published iteration.
struct Config {
    static let predictionKey = "YOUR_AZURE_CUSTOM_VISION_PREDICTION_KEY"
    static let endpoint = "https://YOUR_RESOURCE-prediction.cognitiveservices.azure.com/customvision/v3.0/Prediction/YOUR_PROJECT_ID/classify/iterations/YOUR_ITERATION_NAME/image"
    static let projectID = "YOUR_PROJECT_ID"
    static let publishedModelName = "YOUR_ITERATION_NAME"
}
