import ArcLakeCore
import SwiftUI

struct M2SheetView: View {
  @Bindable var model: M2Model
  let sheet: M2Sheet

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text(title)
        .font(.system(size: 26, weight: .bold, design: .serif))
      content
      HStack {
        Spacer()
        Button("Cancel") { model.sheet = nil }
          .keyboardShortcut(.cancelAction)
        if let primaryTitle {
          Button(primaryTitle) { submit() }
            .keyboardShortcut(.defaultAction)
            .disabled(model.isBusy)
        }
      }
    }
    .padding(26)
    .frame(width: sheetWidth)
    .frame(minHeight: 180)
    .background(
      LinearGradient(
        colors: [Color(hex: "#F9F5EC"), Color(hex: "#E8F0F4")],
        startPoint: .topLeading, endPoint: .bottomTrailing))
  }

  private var title: String {
    switch sheet {
    case .newProfile: "New Profile"
    case .newSpace: "New Space"
    case .editSpace: "Edit Space"
    case .profiles: "Profiles"
    case .copyLink: "Copy Link to Profile"
    case .changeSpaceProfile: "Change Space Profile"
    case .newFolder: "New Folder"
    case .renameItem: "Rename"
    }
  }

  private var primaryTitle: String? {
    switch sheet {
    case .newProfile: "Create Profile"
    case .newSpace: "Create Space"
    case .editSpace: "Save Space"
    case .copyLink: "Copy Link"
    case .changeSpaceProfile: "Continue"
    case .newFolder: "Create Folder"
    case .renameItem: "Rename"
    case .profiles: nil
    }
  }

  private var sheetWidth: CGFloat {
    switch sheet {
    case .profiles: 620
    default: 500
    }
  }

  @ViewBuilder
  private var content: some View {
    switch sheet {
    case .newProfile:
      TextField("Profile name", text: $model.draftName)
        .textFieldStyle(.roundedBorder)
      Text("ArcLake assigns a new persistent WebKit data store UUID and a separate history.")
        .font(.caption)
        .foregroundStyle(.secondary)

    case .newSpace, .editSpace:
      spaceEditor(includeProfile: isNewSpace)

    case .profiles:
      profileList

    case .copyLink(let itemID):
      profilePicker
      Text("Only the URL and title are copied. Cookies, history and form state stay behind.")
        .font(.caption)
        .foregroundStyle(.orange)
      Button("Copy to selected Profile") {
        Task { await model.copyLink(itemID) }
      }
      .disabled(model.draftProfileID == nil)

    case .changeSpaceProfile:
      profilePicker
      Text("Open pages are released and recreated using the target Profile's WebKit data store.")
        .font(.caption)
        .foregroundStyle(.orange)

    case .newFolder:
      TextField("Folder name", text: $model.draftName)
        .textFieldStyle(.roundedBorder)

    case .renameItem:
      TextField("Name", text: $model.draftName)
        .textFieldStyle(.roundedBorder)
    }
  }

  private var isNewSpace: Bool {
    if case .newSpace = sheet { return true }
    return false
  }

  private func spaceEditor(includeProfile: Bool) -> some View {
    VStack(alignment: .leading, spacing: 13) {
      TextField("Space name", text: $model.draftName)
        .textFieldStyle(.roundedBorder)
      TextField("SF Symbol name", text: $model.draftIcon)
        .textFieldStyle(.roundedBorder)
      if includeProfile {
        profilePicker
      }
      Text("Theme")
        .font(.caption.bold())
        .foregroundStyle(.secondary)
      HStack(spacing: 10) {
        ForEach(themePalettes, id: \.accent) { palette in
          Button {
            model.draftBackgroundHex = palette.background
            model.draftAccentHex = palette.accent
          } label: {
            RoundedRectangle(cornerRadius: 10)
              .fill(Color(hex: palette.background))
              .frame(width: 46, height: 34)
              .overlay {
                Circle()
                  .fill(Color(hex: palette.accent))
                  .frame(width: 12, height: 12)
              }
              .overlay {
                RoundedRectangle(cornerRadius: 10)
                  .stroke(
                    model.draftAccentHex == palette.accent
                      ? Color.primary : Color.clear,
                    lineWidth: 2)
              }
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private var profilePicker: some View {
    Picker("Profile", selection: $model.draftProfileID) {
      ForEach(model.activeProfiles) { profile in
        Text(profile.name).tag(Optional(profile.id))
      }
    }
    .pickerStyle(.menu)
  }

  private var profileList: some View {
    VStack(alignment: .leading, spacing: 10) {
      Button {
        model.presentNewProfile()
      } label: {
        Label("New Profile", systemImage: "person.badge.plus")
      }
      ScrollView {
        VStack(spacing: 8) {
          ForEach(model.workspace?.profiles ?? []) { profile in
            let spaces =
              model.workspace?.spaces.filter {
                $0.profileID == profile.id
              } ?? []
            let pending = model.workspace?.pendingOperations.first {
              $0.targetID == profile.id.rawValue
            }
            HStack(spacing: 12) {
              Circle()
                .fill(
                  Color(
                    hex: spaces.first?.theme.accentColorHex
                      ?? "#1D4F7A")
                )
                .frame(width: 11, height: 11)
              VStack(alignment: .leading, spacing: 2) {
                Text(profile.name).font(.headline)
                Text(
                  profile.lifecycle == .deleting
                    ? "Deleting · \(spaces.count) Space(s)"
                    : "\(spaces.count) Space(s)"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                if let pending, let error = pending.lastError {
                  Text(error)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
                }
              }
              Spacer()
              if profile.lifecycle == .deleting, pending != nil {
                Button("Retry") {
                  Task { await model.retryProfileDeletion(profile.id) }
                }
                .disabled(model.isBusy)
              } else {
                if let firstSpace = spaces.first {
                  Button("Open") {
                    Task {
                      await model.switchSpace(firstSpace.id)
                      model.sheet = nil
                    }
                  }
                }
                Button("Delete", role: .destructive) {
                  model.requestDeleteProfile(profile.id)
                }
                .disabled(
                  !spaces.isEmpty || model.activeProfiles.count <= 1
                    || model.isBusy)
              }
            }
            .padding(12)
            .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
          }
        }
      }
      .frame(maxHeight: 360)
    }
  }

  private func submit() {
    switch sheet {
    case .newProfile:
      Task { await model.createProfile() }
    case .newSpace:
      Task { await model.createSpace() }
    case .editSpace(let spaceID):
      Task { await model.updateSpace(spaceID) }
    case .newFolder(let parent):
      Task { await model.createFolder(parent: parent) }
    case .renameItem(let itemID):
      Task { await model.rename(itemID: itemID) }
    case .copyLink(let itemID):
      Task { await model.copyLink(itemID) }
    case .changeSpaceProfile(let spaceID):
      model.confirmChangeSpaceProfile(spaceID)
    case .profiles:
      break
    }
  }

  private var themePalettes: [(background: String, accent: String)] {
    [
      ("#E8EEF5", "#1D4F7A"),
      ("#F6EBDD", "#8A4E2D"),
      ("#E9EFE2", "#496B2F"),
      ("#F4E6E5", "#8E3B46"),
      ("#E7E4F0", "#574C7A"),
      ("#E6F0F0", "#236F73"),
    ]
  }
}
