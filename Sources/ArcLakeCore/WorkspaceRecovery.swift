import Foundation

public struct WorkspaceRepair: Equatable, Sendable {
  public let message: String

  public init(_ message: String) {
    self.message = message
  }
}

public enum WorkspaceSelectionRepair {
  @discardableResult
  public static func normalize(_ state: inout WorkspaceState) -> [WorkspaceRepair] {
    var repairs: [WorkspaceRepair] = []
    let orderedSpaces = state.spaces.sorted {
      if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
      return $0.id < $1.id
    }
    let fallbackSpaceID =
      orderedSpaces.first {
        $0.profileID == state.settings.defaultProfileID
      }?.id ?? orderedSpaces.first?.id

    for index in state.spaces.indices {
      let current = state.spaces[index].selectedItemID
      if let current, state.validSelection(current, in: state.spaces[index]) {
        continue
      }
      let fallback = state.fallbackSelection(in: state.spaces[index].id)
      state.spaces[index].selectedItemID = fallback
      if current != fallback {
        repairs.append(
          WorkspaceRepair(
            "Space \(state.spaces[index].id) selection repaired to \(fallback?.description ?? "none")"
          ))
      }
    }

    for index in state.windows.indices {
      let window = state.windows[index]
      var selectedSpaceID = window.selectedSpaceID
      if selectedSpaceID.flatMap({ state.space($0) }) == nil {
        selectedSpaceID = fallbackSpaceID
        repairs.append(
          WorkspaceRepair(
            "Window \(window.id) selected Space repaired to \(selectedSpaceID?.description ?? "none")"
          ))
      }
      state.windows[index].selectedSpaceID = selectedSpaceID
      guard let selectedSpaceID, let space = state.space(selectedSpaceID) else {
        state.windows[index].selectedItemID = nil
        state.windows[index].selectedPaneID = nil
        continue
      }

      var selectedItemID = window.selectedItemID
      if selectedItemID.map({ state.validSelection($0, in: space) }) != true {
        selectedItemID = space.selectedItemID ?? state.fallbackSelection(in: space.id)
        if window.selectedItemID != selectedItemID {
          repairs.append(
            WorkspaceRepair(
              "Window \(window.id) item repaired to \(selectedItemID?.description ?? "none")"))
        }
      }
      state.windows[index].selectedItemID = selectedItemID
      state.windows[index].selectedPaneID = validPane(
        window.selectedPaneID, itemID: selectedItemID, state: state)

      let validSelections = window.lastSelections.filter { selection in
        guard let rememberedSpace = state.space(selection.spaceID) else { return false }
        return state.validSelection(selection.itemID, in: rememberedSpace)
      }
      if validSelections != window.lastSelections {
        repairs.append(
          WorkspaceRepair(
            "Window \(window.id) remembered selections were pruned"))
      }
      state.windows[index].lastSelections = validSelections
    }
    return repairs
  }

  private static func validPane(
    _ paneID: ItemID?, itemID: ItemID?,
    state: WorkspaceState
  ) -> ItemID? {
    guard let paneID, let itemID, state.split(itemID) != nil,
      state.children(of: itemID).contains(where: { $0.id == paneID })
    else {
      return nil
    }
    return paneID
  }
}

public struct RestorationPlan: Equatable, Sendable {
  public var windowID: WindowID
  public var spaceID: SpaceID
  public var selectedItemID: ItemID?
  public var selectedPaneID: ItemID?
  public var tabIDs: [TabID]

  public init(
    windowID: WindowID, spaceID: SpaceID, selectedItemID: ItemID?,
    selectedPaneID: ItemID?, tabIDs: [TabID]
  ) {
    self.windowID = windowID
    self.spaceID = spaceID
    self.selectedItemID = selectedItemID
    self.selectedPaneID = selectedPaneID
    self.tabIDs = tabIDs
  }
}

public enum RestorationPlanner {
  public static func plan(
    for windowID: WindowID,
    in state: WorkspaceState
  ) -> RestorationPlan? {
    guard let window = state.window(windowID),
      let spaceID = window.selectedSpaceID,
      let space = state.space(spaceID)
    else { return nil }
    let selectedItemID =
      window.selectedItemID ?? space.selectedItemID
      ?? state.fallbackSelection(in: space.id)
    let tabIDs = selectedItemID.map { visibleTabs(in: $0, state: state) } ?? []
    return RestorationPlan(
      windowID: window.id,
      spaceID: space.id,
      selectedItemID: selectedItemID,
      selectedPaneID: window.selectedPaneID,
      tabIDs: tabIDs
    )
  }

  private static func visibleTabs(
    in itemID: ItemID,
    state: WorkspaceState
  ) -> [TabID] {
    guard let item = state.item(itemID) else { return [] }
    switch item.kind {
    case .tab:
      return item.tabID.map { [$0] } ?? []
    case .split:
      return state.children(of: itemID).compactMap(\.tabID)
    case .folder:
      return state.children(of: itemID).lazy.compactMap { child in
        visibleTabs(in: child.id, state: state).first
      }.first.map { [$0] } ?? []
    }
  }
}
