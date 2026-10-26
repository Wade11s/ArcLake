import Foundation

public enum CommandBarMode: String, Equatable, Sendable {
  case newTab
  case navigateCurrent
}

public enum CommandCandidateKind: String, Equatable, Sendable {
  case applicationCommand
  case space
  case activeItem
  case history
  case url
  case search
}

public enum CommandAction: Equatable, Sendable {
  case openURLNewTab(URL)
  case navigateCurrent(URL)
  case selectSpace(SpaceID)
  case selectItem(ItemID)
  case application(AppCommand)
}

public struct CommandCandidate: Identifiable, Equatable, Sendable {
  public var id: String
  public var title: String
  public var subtitle: String
  public var kind: CommandCandidateKind
  public var action: CommandAction
  public var enabled: Bool

  public init(
    id: String, title: String, subtitle: String,
    kind: CommandCandidateKind, action: CommandAction,
    enabled: Bool = true
  ) {
    self.id = id
    self.title = title
    self.subtitle = subtitle
    self.kind = kind
    self.action = action
    self.enabled = enabled
  }
}

public enum AppCommand: String, CaseIterable, Equatable, Sendable {
  case toggleSidebar
  case newTab
  case navigateCurrent
  case closeTab
  case pinOrUnpinSelected
  case favoriteOrUnfavoriteSelected
  case newFolder
  case newProfile
  case newSpace

  public var title: String {
    switch self {
    case .toggleSidebar: "Toggle Sidebar"
    case .newTab: "New Tab"
    case .navigateCurrent: "Edit Current Address"
    case .closeTab: "Close Current Tab"
    case .pinOrUnpinSelected: "Pin or Unpin Selected"
    case .favoriteOrUnfavoriteSelected: "Favorite or Unfavorite Selected"
    case .newFolder: "New Folder"
    case .newProfile: "New Profile"
    case .newSpace: "New Space"
    }
  }
}

public struct AppCommandDescriptor: Equatable, Sendable {
  public var command: AppCommand
  public var title: String
  public var shortcut: String
  public var enabled: Bool

  public init(
    command: AppCommand, title: String, shortcut: String, enabled: Bool
  ) {
    self.command = command
    self.title = title
    self.shortcut = shortcut
    self.enabled = enabled
  }
}

public struct CommandContext: Equatable, Sendable {
  public var windowID: WindowID
  public var selectedItemID: ItemID?
  public var selectedSpaceID: SpaceID?

  public init(
    windowID: WindowID, selectedItemID: ItemID?, selectedSpaceID: SpaceID?
  ) {
    self.windowID = windowID
    self.selectedItemID = selectedItemID
    self.selectedSpaceID = selectedSpaceID
  }
}

public enum CommandRegistry {
  public static func descriptors(
    state: WorkspaceState, context: CommandContext
  ) -> [AppCommandDescriptor] {
    let selected = context.selectedItemID.flatMap(state.item)
    let selectedTab = selected?.tabID.flatMap(state.tab)
    let region = context.selectedItemID.flatMap(state.region)
    return [
      AppCommandDescriptor(
        command: .toggleSidebar, title: AppCommand.toggleSidebar.title,
        shortcut: "⌘S", enabled: true),
      AppCommandDescriptor(
        command: .newTab, title: AppCommand.newTab.title,
        shortcut: "⌘T", enabled: context.selectedSpaceID != nil),
      AppCommandDescriptor(
        command: .navigateCurrent, title: AppCommand.navigateCurrent.title,
        shortcut: "⌘L", enabled: selectedTab != nil),
      AppCommandDescriptor(
        command: .closeTab, title: AppCommand.closeTab.title,
        shortcut: "⌘W", enabled: selectedTab != nil),
      AppCommandDescriptor(
        command: .pinOrUnpinSelected,
        title: AppCommand.pinOrUnpinSelected.title,
        shortcut: "⌘D",
        enabled: selected != nil && selected?.kind != .folder
          && (region == .today || region == .pinned)),
      AppCommandDescriptor(
        command: .favoriteOrUnfavoriteSelected,
        title: AppCommand.favoriteOrUnfavoriteSelected.title,
        shortcut: "",
        enabled: selected?.kind == .tab && region != nil),
      AppCommandDescriptor(
        command: .newFolder, title: AppCommand.newFolder.title,
        shortcut: "",
        enabled: context.selectedSpaceID != nil
          && (region == .pinned || selected?.kind == .folder)),
      AppCommandDescriptor(
        command: .newProfile, title: AppCommand.newProfile.title,
        shortcut: "", enabled: true),
      AppCommandDescriptor(
        command: .newSpace, title: AppCommand.newSpace.title,
        shortcut: "", enabled: true),
    ]
  }
}

public enum CommandBarEngine {
  public static func candidates(
    query: String,
    mode: CommandBarMode,
    state: WorkspaceState,
    context: CommandContext,
    history: [HistoryVisit],
    limit: Int = 30
  ) -> [CommandCandidate] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let spaceID = context.selectedSpaceID,
      let space = state.space(spaceID),
      let profile = state.profile(space.profileID)
    else { return [] }

    var result: [CommandCandidate] = []
    let lowered = trimmed.lowercased()

    for descriptor in CommandRegistry.descriptors(state: state, context: context)
    where descriptor.enabled
      && (trimmed.isEmpty || descriptor.title.lowercased().contains(lowered))
    {
      result.append(
        CommandCandidate(
          id: "command:\(descriptor.command.rawValue)",
          title: descriptor.title,
          subtitle: descriptor.shortcut.isEmpty
            ? "Application command" : descriptor.shortcut,
          kind: .applicationCommand,
          action: .application(descriptor.command)))
    }

    for candidateSpace in state.spaces
    where candidateSpace.profileID == profile.id
      && (trimmed.isEmpty || candidateSpace.name.lowercased().contains(lowered))
    {
      result.append(
        CommandCandidate(
          id: "space:\(candidateSpace.id)",
          title: candidateSpace.name,
          subtitle: "Switch Space",
          kind: .space,
          action: .selectSpace(candidateSpace.id)))
    }

    if let url = navigationURL(trimmed, profile: profile) {
      let isExplicitURL =
        trimmed.lowercased().hasPrefix("http://")
        || trimmed.lowercased().hasPrefix("https://")
      result.append(
        CommandCandidate(
          id: "url:\(url.absoluteString)",
          title: isExplicitURL ? url.absoluteString : "Search for “\(trimmed)”",
          subtitle: url.host ?? "Search",
          kind: isExplicitURL ? .url : .search,
          action: mode == .newTab
            ? .openURLNewTab(url) : .navigateCurrent(url)))
    }

    let activeItems = visibleItems(profileID: profile.id, state: state)
      .filter { item in
        guard let tab = item.tabID.flatMap(state.tab) else { return false }
        let haystack = [
          item.customTitle, tab.pageTitle, tab.currentURL?.absoluteString,
          tab.savedURL?.absoluteString,
        ].compactMap { $0 }.joined(separator: " ").lowercased()
        return trimmed.isEmpty || haystack.contains(lowered)
      }
    for item in activeItems.prefix(8) {
      let tab = item.tabID.flatMap(state.tab)
      result.append(
        CommandCandidate(
          id: "item:\(item.id)",
          title: item.customTitle ?? tab?.pageTitle ?? "Untitled",
          subtitle: tab?.currentURL?.host ?? "Active Tab",
          kind: .activeItem,
          action: .selectItem(item.id)))
    }

    for visit in history
    where visit.profileID == profile.id
      && (trimmed.isEmpty
        || visit.url.absoluteString.lowercased().contains(lowered)
        || (visit.title?.lowercased().contains(lowered) ?? false))
    {
      result.append(
        CommandCandidate(
          id: "history:\(visit.id)",
          title: visit.title ?? visit.url.absoluteString,
          subtitle: visit.url.absoluteString,
          kind: .history,
          action: mode == .newTab
            ? .openURLNewTab(visit.url) : .navigateCurrent(visit.url)))
    }

    if trimmed.lowercased().hasPrefix("http://")
      || trimmed.lowercased().hasPrefix("https://"),
      let index = result.firstIndex(where: { $0.kind == .url })
    {
      let urlCandidate = result.remove(at: index)
      result.insert(urlCandidate, at: 0)
    }
    return Array(result.prefix(max(0, limit)))
  }

  private static func navigationURL(
    _ input: String, profile: Profile
  ) -> URL? {
    guard !input.isEmpty else { return nil }
    if let url = URL(string: input), let scheme = url.scheme?.lowercased() {
      return scheme == "http" || scheme == "https" ? url : nil
    }
    let encoded =
      input.addingPercentEncoding(
        withAllowedCharacters: .urlQueryAllowed) ?? input
    return URL(
      string: profile.searchEngineTemplate.replacingOccurrences(
        of: "{query}", with: encoded))
  }

  private static func visibleItems(
    profileID: ProfileID, state: WorkspaceState
  ) -> [SidebarItem] {
    state.items
      .filter {
        $0.kind == .tab
          && state.profile(forItemID: $0.id)?.id == profileID
      }
      .sorted(by: SidebarItem.order)
  }
}
