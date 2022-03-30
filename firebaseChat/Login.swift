//
//  ContentView.swift
//  firebaseChat
//
//  Created by tungtran on 26/03/2022.
//

import SwiftUI
import Firebase

struct Login: View {
    @State private var isLoginMode = true
    @State private var email = ""
    @State private var password = ""
    @State var loginErrorMessage = ""
    @State private var shouldShowImagePicker = false
    @State var image: UIImage?
    
    let disCompleteLoginProcess: () -> ()
    
    var body: some View {
        NavigationView{
            ScrollView{
                VStack(spacing: 16){
                    Picker(selection: $isLoginMode, label:Text("Picker here")){
                        Text("Login").tag(true)
                        Text("Create Account").tag(false)
                    }.pickerStyle(SegmentedPickerStyle())
                        .padding()
                    
                    if !isLoginMode {
                        Button {
                            shouldShowImagePicker.toggle()
                        } label: {
                            VStack {
                                if let image = self.image {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 128, height: 128)
                                        .cornerRadius(64)
                                } else {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 64))
                                        .padding()
                                        .foregroundColor(Color(.label))
                                }
                            }
                            .overlay(RoundedRectangle(cornerRadius: 64)
                                        .stroke(Color.black, lineWidth: 3)
                            )
                        }
                    }
                    Group{
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        SecureField("Password", text: $password)
                    }
                    .background(Color.white)
                    .padding(12)
                    
                    
                    Button{
                        handleAction()
                    } label: {
                        HStack{
                            Spacer()
                            Text(isLoginMode ? "Login": "Create Account")
                                .foregroundColor(.white)
                                .padding(.vertical, 10)
                            Spacer()
                        }.background(Color.blue)
                        
                    }
                    Text(self.loginErrorMessage)
                        .foregroundColor(.red)
                }.padding()
                
                
            }
            .background(Color(.init(white: 0, alpha: 0.05)))
            .navigationTitle(isLoginMode ? "Login": "Create Account")
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .fullScreenCover(isPresented: $shouldShowImagePicker, onDismiss: nil) {
            ImagePicker(image: $image)
                .ignoresSafeArea()
        }
        
    }
    
    private func handleAction (){
        if isLoginMode{
            print("Should log inti Firebase")
            loginUser()
        }else{
            print("Register Firebase")
            createNewAccount()
        }
    }
    
    private func loginUser(){
        FirebaseManager.shared.auth.signIn(withEmail: email, password: password) { result, err in
            if let err = err{
                print("Failed to create user:", err)
                self.loginErrorMessage = "Failed to login user: \(err)"
                return
            }
            print("Success created user: \(result?.user.uid ?? "")")
            self.loginErrorMessage  = "Success login user: \(result?.user.uid ?? "")"
            self.disCompleteLoginProcess()
        }
    }
    
    private func createNewAccount (){
        if self.image == nil {
            self.loginErrorMessage = "You must select an avatar image"
            return
        }
        FirebaseManager.shared.auth.createUser(withEmail: email, password: password) { result, err in
            if let err = err{
                print("Failed to create user:", err)
                self.loginErrorMessage = "Failed to create user: \(err)"
                return
            }
            print("Success created user: \(result?.user.uid ?? "")")
            self.loginErrorMessage  = "Success created user: \(result?.user.uid ?? "")"
            self.persistImageToStorage()
        }
    }
    
    private func persistImageToStorage() {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        let ref = FirebaseManager.shared.storage.reference(withPath: uid)
        guard let imageData = self.image?.jpegData(compressionQuality: 0.5) else { return }
        ref.putData(imageData, metadata: nil) { metadata, err in
            if let err = err {
                self.loginErrorMessage = "Failed to push image to Storage: \(err)"
                return
            }
            
            ref.downloadURL { url, err in
                if let err = err {
                    self.loginErrorMessage = "Failed to retrieve downloadURL: \(err)"
                    return
                }
                
                self.loginErrorMessage = "Successfully stored image with url: \(url?.absoluteString ?? "")"
                print(url?.absoluteString)
                
                guard let url = url else {return}
                self.storeUserInformation(imageProfileUrl: url)
            }
        }
    }
    private func storeUserInformation(imageProfileUrl: URL) {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        let userData = ["email": self.email, "uid": uid, "profileImageUrl": imageProfileUrl.absoluteString]
        FirebaseManager.shared.firestore.collection("users")
            .document(uid).setData(userData) { err in
                if let err = err {
                    print(err)
                    self.loginErrorMessage = "\(err)"
                    return
                }
                self.disCompleteLoginProcess()
            }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Login(disCompleteLoginProcess:{})
    }
}
