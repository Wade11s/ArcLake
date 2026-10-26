import ArcLakeCore
import SwiftUI

struct M2SidebarView: View {
  @Bindable var model: M2Model

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider().opacity(0.45)
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          favoritesSection
          pinnedSection
          todaySection
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
      }
      Divider().opacity(0.45)
      spaceRail
    }
    .background(.ultraThinMaterial)
  }

  private var header: some View {
    HStack(spacing: 10) {
      Circle()
        .fill(Color(hex: model.selectedSpace?.theme.accentColorHex ?? "#1D4F7A"))
        .frame(width: 11, height: 11)
        .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 1))
      VStack(alignment: .leading, spacing: 1) {
        Text("ArcLake")
          .font(.system(.headline, design: .serif, weight: .bold))
        Text(model.currentProfile?.name ?? "No Profile")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Button {
        model.presentProfiles()
      } label: {
        Image(systemName: "person.2.crop.square.stack")
      }
      .buttonStyle(.plain)
      .help("Manage Profiles")
      Button {
        model.toggleSidebar()
      } label: {
        Image(systemName: "sidebar.left")
      }
      .buttonStyle(.plain)
      .help("Hide Sidebar")
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
  }

  @ViewBuilder
  private var favoritesSection: some View {
    if let favoritesRoot = model.favoritesRoot,
      let items = model.workspace?.children(of: .root(favoritesRoot.id)),
      !items.isEmpty
    {
      SidebarSectionHeader(title: "Favorites", icon: "star.fill")
      ForEach(items) { item in
        SidebarTabRow(model: model, item: item, depth: 0)
      }
    }
  }

  @ViewBuilder
  private var pinnedSection: some View {
    if let space = model.selectedSpace {
      SidebarSectionHeader(title: "Pinned", icon: "pin.fill") {
        Button {
          model.presentNewFolder(parent: .root(space.pinnedRootID))
        } label: {
          Image(systemName: "folder.badge.plus")
        }
        .buttonStyle(.plain)
      }
      VStack(alignment: .leading, spacing: 3) {
        let items = model.workspace?.children(of: .root(space.pinnedRootID)) ?? []
        if items.isEmpty {
          Text("Drag a Today item here or create a Folder")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)
        } else {
          ForEach(items) { item in
            SidebarNodeView(model: model, item: item, depth: 0)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
      .dropDestination(for: String.self) { values, _ in
        guard let value = values.first else { return false }
        Task {
          await model.moveDraggedItem(
            value, to: .root(space.pinnedRootID))
        }
        return true
      }
    }
  }

  @ViewBuilder
  private var todaySection: some View {
    if let space = model.selectedSpace {
      SidebarSectionHeader(title: "Today", icon: "sun.max.fill")
      VStack(alignment: .leading, spacing: 3) {
        let items = model.workspace?.children(of: .root(space.todayRootID)) ?? []
        if items.isEmpty {
          Text("No open pages")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)
        } else {
          ForEach(items) { item in
            SidebarNodeView(model: model, item: item, depth: 0)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
      .dropDestination(for: String.self) { values, _ in
        guard let value = values.first else { return false }
        Task {
          await model.moveDraggedItem(
            value, to: .root(space.todayRootID))
        }
        return true
      }
    }
  }

  private var spaceRail: some View {
    HStack(spacing: 8) {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(Array(model.currentSpaces.enumerated()), id: \.element.id) {
            index, space in
            Button {
              Task { await model.switchSpace(space.id) }
            } label: {
              VStack(spacing: 4) {
                ZStack {
                  RoundedRectangle(cornerRadius: 9)
                    .fill(
                      space.id == model.selectedSpaceID
                        ? Color(hex: space.theme.accentColorHex)
                        : Color.primary.opacity(0.08)
                    )
                    .frame(width: 34, height: 34)
                  Image(systemName: space.icon)
                    .foregroundStyle(
                      space.id == model.selectedSpaceID ? .white : .primary)
                }
                Text(space.name)
                  .font(.caption2)
                  .lineLimit(1)
                  .frame(width: 54)
              }
            }
            .buttonStyle(.plain)
            .contextMenu {
              Button("Edit Space…") { model.presentEditSpace(space.id) }
              Button("Move Left") {
                Task { await model.moveSpace(space.id, direction: .up) }
              }
              .disabled(index == 0)
              Button("Move Right") {
                Task { await model.moveSpace(space.id, direction: .down) }
              }
              .disabled(index == model.currentSpaces.count - 1)
              Divider()
              Button("Change Profile…") {
                model.presentChangeSpaceProfile(space.id)
              }
            }
          }
        }
      }
      Button {
        model.presentNewSpace()
      } label: {
        Image(systemName: "plus")
          .frame(width: 30, height: 30)
          .background(Color.primary.opacity(0.08), in: Circle())
      }
      .buttonStyle(.plain)
      .help("New Space")
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
  }
}

private struct SidebarSectionHeader<Accessory: View>: View {
  let title: String
  let icon: String
  @ViewBuilder let accessory: () -> Accessory

  init(
    title: String, icon: String,
    @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }
  ) {
    self.title = title
    self.icon = icon
    self.accessory = accessory
  }

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: icon)
        .font(.caption2)
      Text(title.uppercased())
        .font(.system(size: 10, weight: .bold, design: .rounded))
        .tracking(1.1)
      Spacer()
      accessory()
    }
    .foregroundStyle(.secondary)
  }
}

private struct SidebarNodeView: View {
  let model: M2Model
  let item: SidebarItem
  let depth: Int
  @State private var expanded = true

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      if item.kind == .folder {
        Button {
          expanded.toggle()
        } label: {
          HStack(spacing: 6) {
            Image(systemName: expanded ? "chevron.down" : "chevron.right")
              .font(.system(size: 9, weight: .bold))
              .frame(width: 10)
            Image(systemName: "folder.fill")
              .foregroundStyle(Color(hex: model.selectedSpace?.theme.accentColorHex ?? "#1D4F7A"))
            Text(item.customTitle ?? "Folder")
              .lineLimit(1)
            Spacer()
          }
          .padding(.leading, CGFloat(depth) * 13)
          .padding(.vertical, 6)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .draggable(item.id.description)
        .dropDestination(for: String.self) { values, _ in
          guard let value = values.first else { return false }
          Task {
            await model.moveDraggedItem(value, to: .item(item.id))
          }
          return true
        }
        .contextMenu { contextMenu }

        if expanded {
          ForEach(model.workspace?.children(of: item.id) ?? []) { child in
            SidebarNodeView(model: model, item: child, depth: depth + 1)
          }
        }
      } else {
        SidebarTabRow(model: model, item: item, depth: depth)
      }
    }
  }

  @ViewBuilder
  private var contextMenu: some View {
    Button("Rename…") { model.presentRename(itemID: item.id) }
    Button("New Folder Inside…") {
      model.presentNewFolder(parent: .item(item.id))
    }
  }
}

private struct SidebarTabRow: View {
  let model: M2Model
  let item: SidebarItem
  let depth: Int

  var body: some View {
    let tab = item.tabID.flatMap { model.workspace?.tab($0) }
    let isSelected = item.id == model.selectedItemID
    Button {
      Task { await model.activateItem(item.id) }
    } label: {
      HStack(spacing: 7) {
        Image(systemName: tab?.currentURL == nil ? "circle.dashed" : "globe")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
        VStack(alignment: .leading, spacing: 1) {
          Text(item.customTitle ?? tab?.pageTitle ?? "Untitled")
            .lineLimit(1)
            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
          if let host = tab?.currentURL?.host {
            Text(host)
              .font(.system(size: 9, design: .monospaced))
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }
        Spacer(minLength: 2)
      }
      .padding(.leading, CGFloat(depth) * 13 + 4)
      .padding(.horizontal, 7)
      .padding(.vertical, 7)
      .background(
        isSelected ? Color.primary.opacity(0.09) : .clear,
        in: RoundedRectangle(cornerRadius: 8)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .draggable(item.id.description)
    .contextMenu {
      let region = model.workspace?.region(of: item.id)
      Button("Rename…") { model.presentRename(itemID: item.id) }
      Button("Pin / Unpin") {
        Task {
          await model.activateItem(item.id)
          await model.togglePinSelected()
        }
      }
      .disabled(
        item.kind == .folder || region == .favorites || region == nil)
      Button("Favorite / Unfavorite") {
        Task {
          await model.activateItem(item.id)
          await model.toggleFavoriteSelected()
        }
      }
      .disabled(item.kind != .tab)
      Button("Reset Pinned URL") {
        Task { await model.resetPinnedItem(item.id) }
      }
      .disabled(region != .pinned)
      Divider()
      Button("Copy Link to Profile…") { model.presentCopyLink(item.id) }
        .disabled(item.kind != .tab)
      Button("Close Tab") {
        guard let tabID = item.tabID else { return }
        Task { await model.closeTab(tabID) }
      }
      .disabled(item.tabID == nil)
    }
  }
}
