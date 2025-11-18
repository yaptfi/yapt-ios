//
//  LoginView.swift
//  Yapt
//
//  Login screen
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @StateObject private var viewModel: LoginViewModel

    init() {
        // ViewModel will be initialized in onAppear with environment
        _viewModel = StateObject(wrappedValue: LoginViewModel(authService: AuthService(
            apiClient: APIClient(),
            sessionManager: SessionManager()
        )))
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Logo/Title
            VStack(spacing: 16) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 72))
                    .foregroundColor(.blue)

                Text("Yapt")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("DeFi Portfolio Tracker")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Login Form
            VStack(spacing: 20) {
                TextField("Username", text: $viewModel.username)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.username)
                    .autocapitalization(.none)
                    .disabled(viewModel.isLoading)
                    .accessibilityLabel("Username")

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("Error: \(errorMessage)")
                }

                Button(action: {
                    Task {
                        await viewModel.login()
                    }
                }) {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        } else {
                            Image(systemName: "person.badge.key")
                            Text("Sign in with Passkey")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.username.isEmpty || viewModel.isLoading ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(viewModel.username.isEmpty || viewModel.isLoading)
                .accessibilityLabel("Sign in with passkey")
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .padding()
        .onAppear {
            // Inject the correct environment services
            let vm = LoginViewModel(authService: appEnvironment.authService)
            _viewModel.wrappedValue = vm
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AppEnvironment())
}
