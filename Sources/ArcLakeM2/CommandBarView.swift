import ArcLakeCore
import SwiftUI

struct M2CommandBarView: View {
  @Bindable var model: M2Model
  @FocusState private var focused: Bool

  var body: some View {
    ZStack(alignment: .top) {
      Color.black.opacity(0.12)
        .ignoresSafeArea()
        .onTapGesture { model.closeCommandBar() }
      VStack(spacing: 0) {
        HStack(spacing: 10) {
          Image(systemName: modeIcon)
            .foregroundStyle(.secondary)
          TextField(modePlaceholder, text: $model.commandQuery)
            .textFieldStyle(.plain)
            .font(.system(size: 17, weight: .medium, design: .rounded))
            .focused($focused)
            .onSubmit {
              Task { await model.submitCommandBar() }
            }
          Text(model.commandBarMode == .newTab ? "NEW TAB" : "NAVIGATE")
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .tracking(0.8)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.08), in: Capsule())
        }
        .padding(.horizontal, 18)
        .frame(height: 54)

        if !model.commandCandidates.isEmpty {
          Divider()
          ScrollView {
            LazyVStack(spacing: 3) {
              ForEach(model.commandCandidates) { candidate in
                Button {
                  model.selectedCandidateID = candidate.id
                  model.closeCommandBar()
                  Task { await model.execute(candidate: candidate) }
                } label: {
                  HStack(spacing: 11) {
                    Image(systemName: icon(for: candidate.kind))
                      .font(.system(size: 12))
                      .frame(width: 22, height: 22)
                      .background(
                        Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 1) {
                      Text(candidate.title)
                        .lineLimit(1)
                      Text(candidate.subtitle)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    }
                    Spacer()
                    if candidate.id == model.selectedCandidateID {
                      Image(systemName: "return")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                  }
                  .padding(.horizontal, 10)
                  .padding(.vertical, 7)
                  .background(
                    candidate.id == model.selectedCandidateID
                      ? Color.primary.opacity(0.08) : .clear,
                    in: RoundedRectangle(cornerRadius: 9)
                  )
                  .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!candidate.enabled)
              }
            }
            .padding(8)
          }
          .frame(maxHeight: 340)
        } else if !model.commandQuery.isEmpty {
          Divider()
          Text("No matching page, Space, history entry or command")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
      }
      .frame(width: 640)
      .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 18))
      .overlay {
        RoundedRectangle(cornerRadius: 18)
          .stroke(.white.opacity(0.6), lineWidth: 1)
      }
      .shadow(color: .black.opacity(0.24), radius: 36, y: 16)
    }
    .onAppear { focused = true }
    .onExitCommand { model.closeCommandBar() }
  }

  private var modeIcon: String {
    model.commandBarMode == .newTab ? "plus.square.fill" : "location.fill"
  }

  private var modePlaceholder: String {
    model.commandBarMode == .newTab
      ? "Search, enter a URL, or run a command"
      : "Enter a URL or search the current Profile"
  }

  private func icon(for kind: CommandCandidateKind) -> String {
    switch kind {
    case .applicationCommand: "command"
    case .space: "circle.grid.2x2"
    case .activeItem: "rectangle.on.rectangle"
    case .history: "clock.arrow.circlepath"
    case .url: "globe"
    case .search: "magnifyingglass"
    }
  }
}
