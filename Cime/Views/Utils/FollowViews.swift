//
//  FollowViews.swift
//  Cime
//
//  Created by Daniel Pappalardo on 03/11/2026.
//

import SwiftUI

/// One button for all three states: Follow -> Requested -> Roped in.
/// Use it everywhere (Crew rows, PersonView, search sheet).
struct FollowButton: View {
    @Environment(CimeStore.self) private var store
    let person: Person
    @State private var confirmUnfollow = false

    private var state: FollowState { store.followState(for: person.userId) }

    var body: some View {
        Button(title) {
            if state == .following {
                confirmUnfollow = true          // unfollowing is destructive: ask first
            } else {
                Task { await store.toggleFollow(person) }   // send or cancel a request
            }
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(state == .none ? Theme.accent : Color.clear)
        .foregroundStyle(state == .none ? Theme.accentForeground : Theme.mutedForeground)
        .overlay(Capsule().stroke(state == .none ? Color.clear : Theme.border))
        .clipShape(Capsule())
        .confirmationDialog("Unfollow @\(person.name)?", isPresented: $confirmUnfollow, titleVisibility: .visible) {
            Button("Unfollow", role: .destructive) {
                Task { await store.toggleFollow(person) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var title: String {
        switch state {
        case .none: "Follow"
        case .requested: "Requested"
        case .following: "Roped in"
        }
    }
}

/// Incoming follow requests: accept or decline.
struct FollowRequestsView: View {
    @Environment(CimeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if store.incomingRequests.isEmpty {
                        Text("No pending requests.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.mutedForeground)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 48)
                    }

                    ForEach(store.incomingRequests) { request in
                        HStack(spacing: 12) {
                            AvatarView(url: request.avatarURL, letter: request.username, size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(request.username).font(.headline)
                                Text("wants to follow you")
                                    .font(.caption)
                                    .foregroundStyle(Theme.mutedForeground)
                            }
                            Spacer()
                            Button("Accept") {
                                Task { await store.acceptRequest(request) }
                            }
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Theme.primary)
                            .foregroundStyle(Theme.primaryForeground)
                            .clipShape(Capsule())

                            Button {
                                Task { await store.declineRequest(request) }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.footnote.weight(.bold))
                                    .padding(8)
                                    .overlay(Circle().stroke(Theme.border))
                            }
                            .foregroundStyle(Theme.mutedForeground)
                            .accessibilityLabel("Decline")
                        }
                        .padding(14)
                        .background(Theme.card)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .navigationTitle("Follow requests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.font(.subheadline.weight(.semibold))
                }
            }
            .refreshable { await store.fetchIncomingRequests() }
            .task { await store.fetchIncomingRequests() }
        }
    }
}
