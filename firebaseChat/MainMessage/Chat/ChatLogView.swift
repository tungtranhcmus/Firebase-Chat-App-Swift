//
//  ChatLogView.swift
//  firebaseChat
//
//  Created by tungtran on 29/03/2022.
//

import SwiftUI
import Firebase

struct FirebaseConstants {
    static let uid = "uid"
    static let fromId = "fromId"
    static let toId = "toId"
    static let text = "text"
    static let timestamp = "timestamp"
    static let profileImageUrl = "profileImageUrl"
    static let email = "email"
}

struct ChatMessage: Identifiable {
    
    var id: String { documentId }
    
    let documentId: String
    let fromId, toId, text: String
    
    init(documentId: String, data: [String: Any]) {
        self.documentId = documentId
        self.fromId = data[FirebaseConstants.fromId] as? String ?? ""
        self.toId = data[FirebaseConstants.toId] as? String ?? ""
        self.text = data[FirebaseConstants.text] as? String ?? ""
    }
}

class ChatLogViewModel: ObservableObject{
    @Published var chatText = ""
    @Published var errorMessage = ""
    @Published var chatMessages = [ChatMessage]()
    @Published var count = 0
    var firestoreListener: ListenerRegistration?
    
    var chatUser: ChatUser?
    private var currentUser: ChatUser?
    
    init(chatUser: ChatUser?) {
        self.chatUser = chatUser
        fetchMessages()
    }
    
    func fetchCurrentUser(){
        
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else {
            self.errorMessage = "Count not find firebase uid"
            return
            
        }
        self.errorMessage = "\(uid)"
        FirebaseManager.shared.firestore.collection("users")
            .document(uid).getDocument{snapshot, error in
                if let error = error {
                    print("Failed to fetch current user:", error)
                    self.errorMessage = "Failed to fetch current user: \(error)"
                }
                guard let data = snapshot?.data() else {
                    self.errorMessage = "No data found"
                    return
                    
                }
                print(data)
                self.currentUser = .init(data: data)
            }
    }

    
    func fetchMessages() {
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let toId = chatUser?.uid else { return }
        firestoreListener?.remove()
        self.chatMessages.removeAll()
        fetchCurrentUser()
        firestoreListener = FirebaseManager.shared.firestore
            .collection("messages")
            .document(fromId)
            .collection(toId)
            .order(by: "timestamp")
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to listen for messages: \(error)"
                    print(error)
                    return
                }
                
                querySnapshot?.documentChanges.forEach({ change in
                    if change.type == .added {
                        let data = change.document.data()
                        self.chatMessages.append(.init(documentId: change.document.documentID, data: data))
                    }
                })
                DispatchQueue.main.async {
                    self.count += 1
                }
                
            }
    }
    
    func handleSend() {
        print(chatText)
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else { return }
        
        guard let toId = chatUser?.uid else { return }
        
        let document = FirebaseManager.shared.firestore.collection("messages")
            .document(fromId)
            .collection(toId)
            .document()
        
        let messageData = ["fromId": fromId, "toId": toId, "text": self.chatText, "timestamp": Timestamp()] as [String : Any]
        
        document.setData(messageData) { error in
            if let error = error {
                print(error)
                self.errorMessage = "Failed to save message into Firestore: \(error)"
                return
            }
            
            print("Successfully saved current user sending message")
            self.persistRecentMessage()
            self.chatText = ""
            self.count += 1
        }
        
        let recipientMessageDocument = FirebaseManager.shared.firestore.collection("messages")
            .document(toId)
            .collection(fromId)
            .document()
        
        recipientMessageDocument.setData(messageData) { error in
            if let error = error {
                print(error)
                self.errorMessage = "Failed to save message into Firestore: \(error)"
                return
            }
            
            print("Recipient saved message as well")
        }
    }
    
    private func persistRecentMessage() {
        guard let chatUser = chatUser else { return }
        
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let toId = self.chatUser?.uid else { return }
        
        let document = FirebaseManager.shared.firestore
            .collection("recent_messages")
            .document(uid)
            .collection("messages")
            .document(toId)
        
        let data = [
            FirebaseConstants.timestamp: Timestamp(),
            FirebaseConstants.text: self.chatText,
            FirebaseConstants.fromId: uid,
            FirebaseConstants.toId: toId,
            FirebaseConstants.profileImageUrl: chatUser.profileImageUrl,
            FirebaseConstants.email: chatUser.email
        ] as [String : Any]
        
        // you'll need to save another very similar dictionary for the recipient of this message...how?
        
        document.setData(data) { error in
            if let error = error {
                self.errorMessage = "Failed to save recent message: \(error)"
                print("Failed to save recent message: \(error)")
                return
            }
        }

        guard let currentUser = FirebaseManager.shared.auth.currentUser else { return }
        let recipientRecentMessageDictionary = [
            FirebaseConstants.timestamp: Timestamp(),
            FirebaseConstants.text: self.chatText,
            FirebaseConstants.fromId: uid,
            FirebaseConstants.toId: toId,
            FirebaseConstants.profileImageUrl: self.currentUser?.profileImageUrl,
            FirebaseConstants.email: currentUser.email
        ] as [String : Any]
        
        FirebaseManager.shared.firestore
            .collection("recent_messages")
            .document(toId)
            .collection("messages")
            .document(currentUser.uid)
            .setData(recipientRecentMessageDictionary) { error in
                if let error = error {
                    print("Failed to save recipient recent message: \(error)")
                    return
                }
            }
    }
}

struct ChatLogView: View {
    
//    let chatUser: ChatUser?
//    init(chatUser: ChatUser?){
//        self.chatUser = chatUser
//        self.vm = .init(chatUser: chatUser)
//    }
    
    @ObservedObject var vm: ChatLogViewModel
    
    var body: some View {
        ZStack{
            messagesView
            Text(vm.errorMessage)
        }
        .navigationTitle(vm.chatUser?.email ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear{
            vm.firestoreListener?.remove()
        }
        
    }
    private var messagesView: some View {
        VStack{
            ScrollView {
                ScrollViewReader{ scrollViewProxy in
                    VStack{
                        ForEach(vm.chatMessages) { message in
                            MessageChat(message: message)
                        }
                        HStack{ Spacer() }
                        .id("Empty")
                    }
                    .onReceive(vm.$count){ _ in
                        withAnimation(.easeOut(duration: 0.5)){
                            scrollViewProxy.scrollTo("Empty", anchor: .bottom)
                        }
                    }
                }
                
            }
            .background(Color(.init(white: 0.95, alpha: 1)))
            .safeAreaInset(edge: .bottom ){
                chatBottomBar
                    .background(Color(.systemBackground).ignoresSafeArea())
            }
        }
        
        
    }
    private var chatBottomBar: some View {
        HStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 24))
                .foregroundColor(Color(.darkGray))
            ZStack {
                DescriptionPlaceholder()
                //                TextField("Description", text: $chatText)
                TextEditor(text: $vm.chatText)
                    .opacity(vm.chatText.isEmpty ? 0.5 : 1)
            }
            .frame(height: 40)
            
            Button {
                vm.handleSend()
            } label: {
                Text("Send")
                    .foregroundColor(.white)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.blue)
            .cornerRadius(4)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct ChatLogView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView{
            ChatLogView(vm: ChatLogViewModel(chatUser: nil))
        }
        
    }
}

struct MessageChat: View {
    let message: ChatMessage
    var body: some View{
        VStack{
            if message.fromId == FirebaseManager.shared.auth.currentUser?.uid{
                HStack {
                    Spacer()
                    HStack {
                        Text(message.text)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
                }
            }else{
                HStack {
                    HStack {
                        Text(message.text)
                            .foregroundColor(.black)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(8)
                    Spacer()
                }
                
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

private struct DescriptionPlaceholder: View {
    var body: some View {
        HStack {
            Text("Description")
                .foregroundColor(Color(.gray))
                .font(.system(size: 17))
                .padding(.leading, 5)
                .padding(.top, -4)
            Spacer()
        }
    }
}
