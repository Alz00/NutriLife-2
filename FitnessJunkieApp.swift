import SwiftUI
import UIKit
import AVFoundation

// MARK: - Data Structures

struct Question {
    let title: String
    let options: [String]
}

enum AppView: String {
    case accountCreation, questionnaire, loading, summary, dashboard
}

enum UserProgress: String {
    case notStarted, inQuestionnaire, completed
}

struct UserProfile: Codable {
    var mainGoal: String
    var healthConcerns: String
    var takingMedications: String
    var diet: String
    var activityLevel: String
    var age: String
    var gender: String
    var preferredForm: String
    var height: String
    var weight: String
    var unitSystem: String
}

// MARK: - Views

struct ContentView: View {
    let questions: [Question]
    let isRunningFromXcode: Bool
    
    @State private var userProfile = UserProfile(mainGoal: "", healthConcerns: "", takingMedications: "", diet: "", activityLevel: "", age: "", gender: "", preferredForm: "", height: "", weight: "", unitSystem: "Metric")
    @State private var currentQuestionIndex = 0
    @State private var isLoading = false
    @State private var showingResults = false
    @State private var showingDashboard = false
    @State private var loadingProgress: Float = 0.0
    @State private var currentView: AppView = .accountCreation // Start with account creation
    @State private var progress: Float = 0.0
    @State private var userProgress: UserProgress = .notStarted
    @State private var selectedTab = 1 // Default to Home
    
    let titleFont = Font.system(size: 34, weight: .bold, design: .default)
    let bodyFont = Font.system(size: 20, weight: .bold, design: .default)
    
    init(questions: [Question], isRunningFromXcode: Bool) {
        self.questions = questions
        self.isRunningFromXcode = isRunningFromXcode

        // Initialize default values for all properties
        _currentView = State(initialValue: .accountCreation)
        _userProgress = State(initialValue: .notStarted)
        _userProfile = State(initialValue: UserProfile(mainGoal: "", healthConcerns: "", takingMedications: "", diet: "", activityLevel: "", age: "", gender: "", preferredForm: "", height: "", weight: "", unitSystem: "Metric"))
        _isLoading = State(initialValue: false)
        _showingResults = State(initialValue: false)
        _showingDashboard = State(initialValue: false)
        _loadingProgress = State(initialValue: 0.0)
        _progress = State(initialValue: 0.0)
        _currentQuestionIndex = State(initialValue: 0)

        // If not running from Xcode, try to load saved data
        if !isRunningFromXcode {
            if let savedProgress = UserDefaults.standard.string(forKey: "userProgress"),
               let progress = UserProgress(rawValue: savedProgress),
               let savedView = UserDefaults.standard.string(forKey: "currentView"),
               let view = AppView(rawValue: savedView),
               let savedProfile = UserDefaults.standard.data(forKey: "userProfile"),
               let decodedProfile = try? JSONDecoder().decode(UserProfile.self, from: savedProfile) {
                _userProgress = State(initialValue: progress)
                _currentView = State(initialValue: view)
                _userProfile = State(initialValue: decodedProfile)
            }
        }
    }
    
    var body: some View {
        ZStack {
            AnimatedGradientBackground()
            
            VStack {
                switch currentView {
                case .accountCreation:
                    AccountCreationView(progress: $progress, currentView: $currentView, userProgress: $userProgress, currentQuestionIndex: $currentQuestionIndex, userProfile: $userProfile)
                case .questionnaire:
                    questionnaireView
                case .loading:
                    loadingView
                case .summary:
                    summaryView
                case .dashboard:
                    DashboardView(currentView: $currentView, userProgress: $userProgress, selectedTab: $selectedTab, userProfile: $userProfile)
                }
            }
        }
        .onAppear {
            if isRunningFromXcode {
                currentView = .accountCreation
                userProgress = .notStarted
            } else {
                loadSavedState()
            }
        }
    }
    
    private func loadSavedState() {
        if let savedProgress = UserDefaults.standard.string(forKey: "userProgress"),
           let progress = UserProgress(rawValue: savedProgress),
           let savedView = UserDefaults.standard.string(forKey: "currentView"),
           let view = AppView(rawValue: savedView),
           let savedProfile = UserDefaults.standard.data(forKey: "userProfile"),
           let decodedProfile = try? JSONDecoder().decode(UserProfile.self, from: savedProfile) {
            userProgress = progress
            currentView = view
            userProfile = decodedProfile
        } else {
            // If no saved state, start from the beginning
            currentView = .accountCreation
            userProgress = .notStarted
        }
    }
    
    var questionnaireView: some View {
        VStack {
            HStack {
                Button(action: {
                    if currentQuestionIndex > 0 {
                        currentQuestionIndex -= 1
                        progress = Float(currentQuestionIndex) / Float(questions.count)
                    } else {
                        currentView = .accountCreation
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                        .padding()
                }
                Spacer()
            }
            
            ProgressView(value: progress)
                .padding()
            
            Spacer()
            
            if currentQuestionIndex < questions.count {
                let question = questions[currentQuestionIndex]
                if question.title.contains("height and weight") {
                    heightWeightQuestionView(question.title)
                } else {
                    questionView(question.title, options: question.options, binding: bindingForQuestion(at: currentQuestionIndex))
                }
            } else {
                startLoadingView
            }
            
            Spacer()
            
            if currentQuestionIndex < questions.count {
                Button(action: {
                    withAnimation {
                        currentQuestionIndex += 1
                        progress = Float(currentQuestionIndex) / Float(questions.count)
                    }
                }) {
                    Text("SKIP")
                        .font(bodyFont)
                        .foregroundColor(.gray)
                        .padding(.bottom)
                }
            }
        }
        .foregroundColor(.white)
        .animation(.easeInOut, value: currentQuestionIndex)
        .transition(.opacity)
        .onAppear {
            userProgress = .inQuestionnaire
            saveUserProgress()
        }
    }
    
    var startLoadingView: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 30) {
                Text("Ready to see your personalized plan?")
                    .font(titleFont)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                
                Button(action: {
                    withAnimation {
                        currentView = .loading
                        progress = 0.8
                    }
                }) {
                    Text("GET MY PLAN")
                        .font(bodyFont)
                        .foregroundColor(.black)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(25)
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            userProgress = .completed
            saveUserProgress()
        }
    }
    
    var loadingView: some View {
        VStack(spacing: 20) {
            Text("Creating Your Personalized Plan")
                .font(titleFont)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(2)
                .padding()
            
            Text("Please wait...")
                .font(bodyFont)
                .foregroundColor(.white)
            
            // New progress bar
            ProgressView(value: loadingProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .white))
                .frame(width: 200)
        }
        .onAppear {
            loadingProgress = 0.0
            let timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
                if loadingProgress < 1.0 {
                    loadingProgress += 0.01
                } else {
                    timer.invalidate()
                    withAnimation {
                        currentView = .summary
                    }
                }
            }
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    var summaryView: some View {
        VStack(spacing: 20) {
            Text("HERE'S YOUR TAILORED PLAN")
                .font(titleFont)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .padding(.top, 60)

            ScrollView {
                VStack(spacing: 15) {
                    ForEach(generateRecommendations(for: userProfile), id: \.self) { recommendation in
                        HStack(alignment: .top, spacing: 10) {
                            Text(recommendation.prefix(2))
                                .font(.system(size: 30))
                            
                            Text(recommendation.dropFirst(2))
                                .font(bodyFont)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(15)
                    }
                }
                .padding()
            }

            Button(action: {
                withAnimation {
                    userProgress = .completed
                    currentView = .dashboard // Navigate to dashboard
                    saveUserProgress()
                }
            }) {
                Text("GO TO DASHBOARD")
                    .font(bodyFont)
                    .foregroundColor(.black)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(25)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .padding(.top, 20)
    }
    
    private func saveUserProgress() {
        UserDefaults.standard.set(userProgress.rawValue, forKey: "userProgress")
        UserDefaults.standard.set(currentView.rawValue, forKey: "currentView")
        if let encodedProfile = try? JSONEncoder().encode(userProfile) {
            UserDefaults.standard.set(encodedProfile, forKey: "userProfile")
        }
    }
    
    func questionView(_ title: String, options: [String], binding: Binding<String>) -> some View {
        VStack(spacing: 20) {
            Text(title)
                .font(titleFont)
                .multilineTextAlignment(.center)
            
            ForEach(options, id: \.self) { option in
                Button(action: {
                    binding.wrappedValue = option
                    withAnimation {
                        currentQuestionIndex += 1
                        progress = Float(currentQuestionIndex) / Float(questions.count)
                    }
                }) {
                    Text(option)
                        .font(bodyFont)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(25)
                }
            }
        }
        .padding()
    }
    
    func heightWeightQuestionView(_ title: String) -> some View {
        VStack(spacing: 30) {
            Text(title)
                .font(titleFont)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)

            Picker("Unit System", selection: $userProfile.unitSystem) {
                Text("Metric").tag("Metric")
                Text("Imperial").tag("Imperial")
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .whiteSegmentedPickerStyle()

            VStack(spacing: 20) {
                HStack {
                    Text("Height:")
                        .foregroundColor(.white)
                    Spacer()
                    if userProfile.unitSystem == "Metric" {
                        HeightPickerMetric(height: $userProfile.height)
                    } else {
                        HeightPickerImperial(height: $userProfile.height)
                    }
                }

                HStack {
                    Text("Weight:")
                        .foregroundColor(.white)
                    Spacer()
                    if userProfile.unitSystem == "Metric" {
                        WeightPickerMetric(weight: $userProfile.weight)
                    } else {
                        WeightPickerImperial(weight: $userProfile.weight)
                    }
                }
            }
            .padding()
            .background(Color.blue.opacity(0.3))
            .cornerRadius(15)

            Button(action: {
                withAnimation {
                    currentQuestionIndex += 1
                    progress = Float(currentQuestionIndex) / Float(questions.count)
                }
            }) {
                Text("Next")
                    .font(bodyFont)
                    .foregroundColor(.black)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(25)
            }
            .padding(.horizontal)
        }
        .padding()
    }
    
    func bindingForQuestion(at index: Int) -> Binding<String> {
        switch index {
        case 0: return $userProfile.mainGoal
        case 1: return $userProfile.activityLevel
        case 2: return $userProfile.healthConcerns
        case 3: return $userProfile.takingMedications
        case 4: return $userProfile.diet
        case 5: return $userProfile.gender
        case 6: return .constant("") // This is for the height and weight question
        default: return .constant("")
        }
    }
}

struct AccountCreationView: View {
    @Binding var progress: Float
    @Binding var currentView: AppView
    @Binding var userProgress: UserProgress
    @Binding var currentQuestionIndex: Int
    @Binding var userProfile: UserProfile

    var body: some View {
        ZStack {
            AnimatedGradientBackground()
            
            VStack(spacing: 20) {
                Text("Create your account")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 50)

                Spacer()

                Button(action: {
                    startQuestionnaire()
                }) {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.black)
                        Text("Sign in with Email")
                            .foregroundColor(.black)
                            .font(.system(size: 18, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(30)
                }
                .padding(.horizontal)

                Button(action: {
                    startQuestionnaire()
                }) {
                    HStack {
                        Image("google-logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                        Text("Sign in with Google")
                            .foregroundColor(.black)
                            .font(.system(size: 18, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(30)
                }
                .padding(.horizontal)

                Button(action: {
                    startQuestionnaire()
                }) {
                    HStack {
                        Image("apple-logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                        Text("Sign in with Apple")
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .cornerRadius(30)
                }
                .padding(.horizontal)

                Spacer()
            }
        }
    }
    
    private func startQuestionnaire() {
        progress = 0.2
        currentView = .questionnaire // Navigate to questionnaire
        userProgress = .inQuestionnaire
        UserDefaults.standard.set(userProgress.rawValue, forKey: "userProgress")
        UserDefaults.standard.set(currentView.rawValue, forKey: "currentView")
    }
}

struct DashboardView: View {
    @Binding var currentView: AppView
    @Binding var userProgress: UserProgress
    @Binding var selectedTab: Int
    @Binding var userProfile: UserProfile  // Add this line

    var body: some View {
        ZStack {
            AnimatedGradientBackground()
            
            VStack(spacing: 20) {
                switch selectedTab {
                case 0:
                    SettingsView()
                case 1:
                    dashboardContent
                case 2:
                    ProfileView(userProfile: $userProfile)
                default:
                    dashboardContent
                }
            }
        }
        .overlay(BottomTabBar(selectedTab: $selectedTab), alignment: .bottom)
        .onAppear {
            userProgress = .completed
            currentView = .dashboard
            saveUserProgress()
        }
    }

    private var dashboardContent: some View {
        VStack(spacing: 20) {
            Text("Dashboard")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 40)

            ScrollView {
                VStack(spacing: 20) {
                    ConsistencyView()
                        .padding()
                        .background(Color(hex: "2a0043"))
                        .cornerRadius(20)
                    
                    Text("Get Started Here")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    VStack(spacing: 15) {
                        ActionItemView(icon: "🥗", title: "Meal Plans", description: "Personalized meals to help you reach your goals.")
                        ActionItemView(icon: "🏋️", title: "Workouts", description: "Personalized exercises to give you faster results.")
                        ActionItemView(icon: "📊", title: "Tracking", description: "Monitor your progress and stay motivated.")
                    }
                }
                .padding(.bottom, 100)
            }
        }
        .padding(.horizontal)
        .padding(.top, -20)
    }

    private func saveUserProgress() {
        UserDefaults.standard.set(userProgress.rawValue, forKey: "userProgress")
        UserDefaults.standard.set(currentView.rawValue, forKey: "currentView")
    }
}

struct ConsistencyView: View {
    @State private var animationProgress: CGFloat = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Consistency is king!")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Text("Just two more workouts to complete this week's target, keep it up!")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
            
            HStack(spacing: 5) {
                ForEach(18...24, id: \.self) { day in
                    VStack(spacing: 5) {
                        Circle()
                            .fill(day < 22 ? Color.green : Color.white.opacity(0.3))
                            .frame(width: 20, height: 20)
                        Text("\(day)")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.vertical, 10)
            
            AnimatedProgressGraph()
                .frame(height: 50)
                .padding(.vertical, 10)
        }
    }
}

struct AnimatedProgressGraph: View {
    @State private var animationProgress: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let midHeight = height / 2
                
                path.move(to: CGPoint(x: 0, y: midHeight))
                
                for i in 0...100 {
                    let x = CGFloat(i) / 100 * width
                    let y = sin(CGFloat(i) / 100 * .pi * 2) * (height / 4) + midHeight
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .trim(from: 0, to: animationProgress)
            .stroke(Color.green, lineWidth: 3)
            .shadow(color: Color.green.opacity(0.3), radius: 3, x: 0, y: 0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0)) {
                animationProgress = 1.0
            }
        }
    }
}

struct ActionItemView: View {
    var icon: String
    var title: String
    var description: String
    
    var body: some View {
        HStack {
            Text(icon)
                .font(.system(size: 40))
                .frame(width: 60, height: 60)
                .background(Color(hex: "2a0043"))
                .cornerRadius(15)
            
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.white)
        }
        .padding()
        .background(Color(hex: "2a0043"))
        .cornerRadius(15)
    }
}

struct BottomTabBar: View {
    @Binding var selectedTab: Int
    @State private var showImagePicker = false
    @State private var image: UIImage?

    var body: some View {
        VStack {
            Spacer()
            HStack {
                TabBarItem(icon: "gearshape", text: "Settings", isSelected: selectedTab == 0)
                    .onTapGesture { selectedTab = 0 }
                
                TabBarItem(icon: "house", text: "Home", isSelected: selectedTab == 1)
                    .onTapGesture { selectedTab = 1 }
                
                TabBarItem(icon: "camera", text: "Scan Meal", isSelected: false)
                    .onTapGesture { showImagePicker = true }
                
                TabBarItem(icon: "person", text: "Profile", isSelected: selectedTab == 2)
                    .onTapGesture { selectedTab = 2 }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(Color.black) // Changed from Color(hex: "2a0043") to Color.black
            .cornerRadius(20)
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
        .background(Color.clear)
        .edgesIgnoringSafeArea(.bottom)
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $image, sourceType: .camera)
        }
    }
}

struct TabBarItem: View {
    var icon: String
    var text: String
    var isSelected: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(isSelected ? .blue : .white)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(isSelected ? .blue : .white)
        }
        .frame(maxWidth: .infinity)
        .opacity(isSelected ? 1.0 : 0.7)
    }
}

struct AnimatedGradientBackground: View {
    @State private var start = UnitPoint(x: 0, y: 0)
    @State private var end = UnitPoint(x: 1, y: 1)
    
    let timer = Timer.publish(every: 1, on: .main, in: .default).autoconnect()
    let colors = [Color.black, Color(hex: "1a0033"), Color(hex: "330066")]
    
    var body: some View {
        LinearGradient(gradient: Gradient(colors: colors), startPoint: start, endPoint: end)
            .edgesIgnoringSafeArea(.all)
            .animation(.easeInOut(duration: 6).repeatForever(), value: start)
            .animation(.easeInOut(duration: 6).repeatForever(), value: end)
            .onReceive(timer) { _ in
                self.start = UnitPoint(x: CGFloat.random(in: 0...1), y: CGFloat.random(in: 0...1))
                self.end = UnitPoint(x: CGFloat.random(in: 0...1), y: CGFloat.random(in: 0...1))
            }
    }
}

// MARK: - Helper Functions

func generateRecommendations(for user: UserProfile) -> [String] {
    var recommendations: [String] = []
    
    switch user.mainGoal {
    case "🏋️ Build Muscle":
        recommendations = [
            " Whey Protein Powder: Supports muscle protein synthesis and is ideal for post-workout recovery.",
            "🔋 Creatine Monohydrate: Enhances strength and power output, increasing muscle mass over time.",
            "🧬 Branched-Chain Amino Acids (BCAAs): Reduces muscle soreness and aids in muscle recovery and growth.",
            " Beta-Alanine: Delays muscle fatigue during intense workouts, improving overall performance."
        ]
        
    case "⚖️ Lose Weight":
        recommendations = [
            "🍵 Green Tea Extract: May boost metabolism and support fat oxidation.",
            "🥕 Fiber Supplements: Promotes satiety and aids in digestive health.",
            "🔥 L-Carnitine: Assists in fat metabolism, helping convert fat into energy.",
            "💧 Conjugated Linoleic Acid (CLA): May help reduce body fat and improve lean muscle mass."
        ]
        if user.diet == "🥬 Vegan" || user.diet == "🥕 Vegetarian" {
            recommendations[3] = "💊 Vitamin B12 Supplement: Addresses common deficiency in plant-based diets and supports energy levels."
        }
        
    case "🏃‍♂️ Boost Endurance":
        recommendations = [
            "⚡ Beta-Alanine: Delays muscle fatigue and improves exercise performance.",
            " Electrolyte Supplements: Maintains hydration and replenishes essential minerals lost through sweat.",
            "🌡️ L-Citrulline: Enhances nitric oxide production, improving blood flow and endurance.",
            "🔋 Beetroot Extract: Increases nitric oxide levels, enhancing stamina and endurance."
        ]
        
    case "💪 Enhance Recovery":
        recommendations = [
            "🐟 Omega-3 Fatty Acids: Reduces inflammation and supports joint health.",
            "🧘 Magnesium: Aids in muscle relaxation and supports sleep quality.",
            "🌿 Turmeric (Curcumin): Has anti-inflammatory properties and may reduce muscle soreness.",
            "🌿 Ashwagandha: Helps reduce stress and cortisol levels, promoting recovery."
        ]
        
    case "🌟 Improve Health":
        recommendations = [
            "🌈 Multivitamin: Provides essential nutrients and supports overall health.",
            "🦴 Calcium and Vitamin D: Maintains bone density and supports bone health.",
            "❤️ Coenzyme Q10: Supports heart health and enhances energy production.",
            "🌱 Probiotics: Supports gut health and improves digestion."
        ]
        
    default: // "✨ Other" or any unspecified goal
        recommendations = [
            "💡 Personalized Consultation: Based on your unique goals, consider a personalized consultation for tailored supplement advice.",
            "🌿 Adaptogenic Herbs: Support overall wellness and help the body adapt to stress.",
            "💤 Melatonin: Supports healthy sleep patterns, essential for recovery and well-being.",
            "💧 Hydration Enhancers: Ensure optimal hydration for overall health."
        ]
    }
    
    return recommendations
}

// MARK: - Extensions

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - App Entry Point

@main
struct FitnessJunkieApp: App {
    @State private var isRunningFromXcode = true
    
    let questions = [
        Question(title: "What's your main fitness goal?", options: ["🏋️ Build Muscle", "⚖️ Lose Weight", "🏃‍♂️ Boost Endurance", "💪 Enhance Recovery", "🌟 Improve Health", "✨ Other"]),
        Question(title: "How often do you exercise?", options: ["Rarely", "1-2 times a week", "3-4 times a week", "5+ times a week"]),
        Question(title: "Any health concerns or allergies?", options: ["Yes", "No"]),
        Question(title: "Taking any medications or supplements?", options: ["Yes", "No"]),
        Question(title: "What's your diet like?", options: ["🍖 Omnivore", "🥕 Vegetarian", "🥬 Vegan", "🐟 Pescatarian", "🌍 Other"]),
        Question(title: "Choose gender", options: ["Male", "Female", "Other", "Prefer not to say"]),
        Question(title: "What's your height and weight?", options: []) // This question will use a custom view
    ]
    
    var body: some Scene {
        WindowGroup {
            ContentView(questions: questions, isRunningFromXcode: isRunningFromXcode)
                .onAppear {
                    isRunningFromXcode = false
                }
        }
    }
}

struct ProfileView: View {
    @Binding var userProfile: UserProfile
    @State private var selectedImage: UIImage?

    var body: some View {
        ZStack {
            AnimatedGradientBackground()
            
            ScrollView {
                VStack(spacing: 20) {
                    Text("Profile")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                    
                    VStack(spacing: 15) {
                        ProfileSection(title: "Personal Information") {
                            Group {
                                ProfileRow(title: "Main Goal", value: userProfile.mainGoal)
                                ProfileRow(title: "Health Concerns", value: userProfile.healthConcerns)
                                ProfileRow(title: "Taking Medications", value: userProfile.takingMedications)
                                ProfileRow(title: "Diet", value: userProfile.diet)
                                ProfileRow(title: "Activity Level", value: userProfile.activityLevel)
                                ProfileRow(title: "Age", value: String(userProfile.age))
                                ProfileRow(title: "Gender", value: userProfile.gender)
                                ProfileRow(title: "Preferred Form", value: userProfile.preferredForm)
                                ProfileRow(title: "Height", value: userProfile.height)
                                ProfileRow(title: "Weight", value: userProfile.weight)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

struct ProfileSection<Content: View>: View {
    let title: String
    let content: () -> Content
    
    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
    }
}

struct ProfileRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(10)
        .foregroundColor(.white)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let content: () -> Content
    
    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
                    .padding(.leading, 10)
            }
            
            VStack(spacing: 1) {
                content()
            }
            .background(Color.black.opacity(0.3))
            .cornerRadius(10)
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(color)
                .cornerRadius(8)
            
            Text(title)
                .foregroundColor(.white)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.clear)
    }
}

struct SettingsView: View {
    var body: some View {
        ZStack {
            AnimatedGradientBackground()
            
            ScrollView {
                VStack(spacing: 20) {
                    Text("Settings")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                    
                    VStack(spacing: 15) {
                        SettingsSection(title: "GENERAL") {
                            SettingsRow(icon: "person.circle", title: "Account", color: .blue)
                            SettingsRow(icon: "bell", title: "Notifications", color: .red)
                            SettingsRow(icon: "tag", title: "Meal Preferences", color: .orange)
                            SettingsRow(icon: "arrow.right.square", title: "Logout", color: .gray)
                        }
                        
                        SettingsSection(title: "FEEDBACK") {
                            SettingsRow(icon: "star", title: "Rate FitnessJunkie", color: .yellow)
                            SettingsRow(icon: "envelope", title: "Send Feedback", color: .purple)
                        }
                        
                        SettingsSection(title: "") {
                            SettingsRow(icon: "trash", title: "Delete account", color: .red)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

// Add these new structures for the pickers
struct HeightPickerMetric: View {
    @Binding var height: String
    @State private var cm = 170

    var body: some View {
        HStack {
            Picker("", selection: $cm) {
                ForEach(100...220, id: \.self) { cm in
                    Text("\(cm) cm")
                        .foregroundColor(.white)
                        .tag(cm)
                }
            }
            .pickerStyle(WheelPickerStyle())
            .frame(width: 150, height: 100)
            .clipped()
            .onChange(of: cm) { newValue in
                height = "\(newValue)"
            }
        }
    }
}

struct HeightPickerImperial: View {
    @Binding var height: String
    @State private var feet = 5
    @State private var inches = 8

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                Picker("Feet", selection: $feet) {
                    ForEach(4...7, id: \.self) { feet in
                        Text("\(feet) ft")
                            .foregroundColor(.white)
                            .tag(feet)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(width: geometry.size.width / 2, height: 100)
                .clipped()
                .compositingGroup()
                .contentShape(Rectangle())

                Picker("Inches", selection: $inches) {
                    ForEach(0...11, id: \.self) { inches in
                        Text("\(inches) in")
                            .foregroundColor(.white)
                            .tag(inches)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(width: geometry.size.width / 2, height: 100)
                .clipped()
                .compositingGroup()
                .contentShape(Rectangle())
            }
        }
        .frame(height: 100)
        .onChange(of: feet) { _ in updateHeight() }
        .onChange(of: inches) { _ in updateHeight() }
    }

    private func updateHeight() {
        height = "\(feet)'\(inches)\""
    }
}

struct WeightPickerMetric: View {
    @Binding var weight: String
    @State private var kg = 70

    var body: some View {
        HStack {
            Picker("", selection: $kg) {
                ForEach(40...150, id: \.self) { kg in
                    Text("\(kg) kg")
                        .foregroundColor(.white)
                        .tag(kg)
                }
            }
            .pickerStyle(WheelPickerStyle())
            .frame(width: 150, height: 100)
            .clipped()
            .onChange(of: kg) { newValue in
                weight = "\(newValue)"
            }
        }
    }
}

struct WeightPickerImperial: View {
    @Binding var weight: String
    @State private var lbs = 150

    var body: some View {
        HStack {
            Picker("", selection: $lbs) {
                ForEach(80...330, id: \.self) { lbs in
                    Text("\(lbs) lbs")
                        .foregroundColor(.white)
                        .tag(lbs)
                }
            }
            .pickerStyle(WheelPickerStyle())
            .frame(width: 150, height: 100)
            .clipped()
            .onChange(of: lbs) { newValue in
                weight = "\(newValue)"
            }
        }
    }
}

extension View {
    func whiteSegmentedPickerStyle() -> some View {
        self.modifier(WhiteSegmentedPickerStyle())
    }
}

struct WhiteSegmentedPickerStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.blue], for: .normal)
                UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
                UISegmentedControl.appearance().backgroundColor = .white
                UISegmentedControl.appearance().selectedSegmentTintColor = .blue
            }
    }
}

