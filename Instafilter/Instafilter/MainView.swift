//
//  MainView.swift
//  Instafilter
//
//  Created by Jemerson Canaya on 3/31/25.
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import PhotosUI
import StoreKit

struct MainView: View {
    @AppStorage("filterCount") var filterCount = 0 // Checks how many time the user used the filter feature
    @AppStorage("hasRequestedReview") var hasRequestedReview = false
    @Environment(\.requestReview) var requestReview // get the reviewer request
    
    @State private var processedImage: Image?
    @State private var filterIntensity = 0.5
    @State private var secondfilterIntensity = 0.5
    @State private var selectedItem: PhotosPickerItem?
    @State private var currentFilter : CIFilter = CIFilter.sepiaTone()
    @State private var beginImage: CIImage?
    
    @State private var showingFilters = false // boolean to show confirmation dialog for filter selection
    
    let context = CIContext()
    
    var filterName: (String) -> String = {
        $0.replacing("CI", with: "")
    }
    
    @State private var inputKey1: String = ""
    @State private var inputKey2: String = ""
    
    var filterIntensityLabel1: String {
        inputKey1.replacing("input", with: "")
    }
    var filterIntensityLabel2: String {
        inputKey2.replacing("input", with: "")
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                
                PhotosPicker(selection: $selectedItem) {
                    if let processedImage {
                        processedImage
                            .resizable()
                            .scaledToFit()
                    } else {
                        ContentUnavailableView("No Picture", systemImage: "photo.badge.plus", description: Text("Tap to import a photo"))
                    }
                }
                .buttonStyle(.plain)
                .onChange(of: selectedItem, loadImage)
                
                
                
                Spacer()
                
                Text(filterName(currentFilter.name))
                    .padding(.horizontal)
                    .textCase(.uppercase)
                    .font(.headline)
                    .fontDesign(.monospaced)
                    .background(.orange)
                    .clipShape(.rect(cornerRadius: 20))
                
                VStack {
                    VStack {
                        Slider(value: $filterIntensity)
                            .onChange(of: filterIntensity, applyProcessing)
                            .disabled(processedImage == nil)
                        Text(filterIntensityLabel1)
                            .textCase(.uppercase)
                            .font(.subheadline)
                            .fontDesign(.monospaced)
                    }
                    .padding()
                    
                    VStack {
                        Slider(value: $secondfilterIntensity)
                            .onChange(of: secondfilterIntensity, applyProcessing)
                            .disabled(processedImage == nil || inputKey2 == "")
                        Text(filterIntensityLabel2)
                            .textCase(.uppercase)
                            .font(.subheadline)
                            .fontDesign(.monospaced)
                    }
                    .padding()
                }
                
                
                
                HStack {
                    Button("Change Filter", action: changeFilter)
                    .padding()
                    .disabled(processedImage == nil)
                    .confirmationDialog("Select a filter", isPresented: $showingFilters) {
                        
                        Button("Crystallize") { setFilter(CIFilter.crystallize()) }
                        Button("Edges") { setFilter(CIFilter.edges()) }
                        Button("Gaussian Blur") { setFilter(CIFilter.gaussianBlur()) }
                        Button("Pixellate") { setFilter(CIFilter.pixellate()) }
                        Button("Sepia Tone") { setFilter(CIFilter.sepiaTone()) }
                        Button("Unsharp Mask") { setFilter(CIFilter.unsharpMask()) }
                        Button("Vignette") { setFilter(CIFilter.vignette()) }
                        Button("Motion Blur") { setFilter(CIFilter.motionBlur()) }
                        Button("Cancel", role: .cancel) { }
                        
                    }
                    
                    Spacer()
                    
                    if let processedImage {
                        ShareLink(item: processedImage, preview: SharePreview("Instafilter image", image: processedImage))
                            .padding()
                    }
                }
            }
            .padding([.horizontal, .bottom])
            .navigationTitle("Instafilter")
        }
    }
    
    func loadImage() {
        Task {
            // Get image data from the photo selected from Photos Picker (which is assigned with property, selectedItem)
            guard let imageData = try await selectedItem?.loadTransferable(type: Data.self) else { return }
            
            // Convert to UIImage from Data coming from the photo picker
            guard let inputImage = UIImage(data: imageData) else { return }
            
            // Asign a variable a CIImage to be used for the filter to work with
            beginImage = CIImage(image: inputImage)
            
            // Apply the CI Image with the filter
            currentFilter.setValue(beginImage, forKey: kCIInputImageKey)
            determineInputKeys()
            applyProcessing()
        }
    }
    
    func changeFilter() {
        showingFilters = true
    }
    
    func applyProcessing() {
        
        // Set Filter's intensity with the property filter's supported input keys
        
        if inputKey1.contains(kCIInputIntensityKey) { currentFilter.setValue(filterIntensity, forKey: kCIInputIntensityKey) }
        if inputKey1.contains(kCIInputRadiusKey) { currentFilter.setValue(filterIntensity * 200, forKey: kCIInputRadiusKey) }
        if inputKey1.contains(kCIInputScaleKey) { currentFilter.setValue(filterIntensity * 10, forKey: kCIInputScaleKey) }
        if inputKey1.contains(kCIInputCenterKey) {
            currentFilter.setValue(CIVector(x: filterIntensity * 100, y: filterIntensity * 100), forKey: kCIInputCenterKey)
        }
        if inputKey1.contains(kCIInputAngleKey) { currentFilter.setValue(filterIntensity, forKey: kCIInputAngleKey) }
        
        if inputKey2.contains(kCIInputIntensityKey) { currentFilter.setValue(secondfilterIntensity, forKey: kCIInputIntensityKey) }
        if inputKey2.contains(kCIInputRadiusKey) { currentFilter.setValue(secondfilterIntensity * 200, forKey: kCIInputRadiusKey) }
        if inputKey2.contains(kCIInputScaleKey) { currentFilter.setValue(secondfilterIntensity * 10, forKey: kCIInputScaleKey) }
        if inputKey2.contains(kCIInputCenterKey) {
            currentFilter.setValue(CIVector(x: secondfilterIntensity * 100, y: secondfilterIntensity * 100), forKey: kCIInputCenterKey)
        }
        if inputKey2.contains(kCIInputAngleKey) { currentFilter.setValue(secondfilterIntensity, forKey: kCIInputAngleKey) }
        
        
        // Read the output image from the filter
        guard let outputImage = currentFilter.outputImage else { return }
        
        // Ask the CIContext to render the image from the output of filter
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return }
        
        // Place the CGImage rendered by the CI Context into our Image? property processImage to be used for SwiftUI views
        /// Create a variable with UIImage based from a CGImage
        let uiImage = UIImage(cgImage: cgImage)
        
        /// Implement a value for the processedImage property with Image based from UIImage
        processedImage = Image(uiImage: uiImage)
        
    }
    
    func determineInputKeys() {
        
        var inputKeys = currentFilter.inputKeys
        inputKeys.removeAll(where: { $0.contains("inputImage") })
        
        print("Input Keys: \(inputKeys)")
        
        if inputKeys.count == 2 {
            inputKey1 = inputKeys[0]
            inputKey2 = inputKeys[1]
        } else {
            inputKey1 = inputKeys[0]
            inputKey2 = ""
        }
        
    }
    
    @MainActor func setFilter(_ filter: CIFilter) {
        currentFilter = filter
        loadImage()
        
        filterCount += 1
        
        if filterCount >= 10 && hasRequestedReview == false {
            requestReview()
            hasRequestedReview = true
        }
    }
}
