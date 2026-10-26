import Foundation

struct SQLiteMigration {
  let version: Int32
  let name: String
  let apply: (SQLiteConnection) throws -> Void

  init(
    version: Int32, name: String,
    apply: @escaping (SQLiteConnection) throws -> Void
  ) {
    self.version = version
    self.name = name
    self.apply = apply
  }
}

enum SQLiteMigrations {
  static func production() -> [SQLiteMigration] {
    [
      SQLiteMigration(version: 1, name: "workspace-v1") { connection in
        try connection.execute(
          """
          CREATE TABLE meta (
              key TEXT PRIMARY KEY NOT NULL,
              value TEXT NOT NULL
          );

          CREATE TABLE profiles (
              id TEXT PRIMARY KEY NOT NULL,
              name TEXT NOT NULL,
              website_store_id TEXT NOT NULL UNIQUE,
              archive_interval_seconds REAL NOT NULL,
              search_engine_template TEXT NOT NULL,
              lifecycle TEXT NOT NULL,
              created_at REAL NOT NULL
          );

          CREATE TABLE spaces (
              id TEXT PRIMARY KEY NOT NULL,
              profile_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
              name TEXT NOT NULL,
              icon TEXT NOT NULL,
              background_color_hex TEXT NOT NULL,
              accent_color_hex TEXT NOT NULL,
              sort_order INTEGER NOT NULL,
              pinned_root_id TEXT NOT NULL,
              today_root_id TEXT NOT NULL,
              selected_item_id TEXT
          );

          CREATE TABLE roots (
              id TEXT PRIMARY KEY NOT NULL,
              kind TEXT NOT NULL,
              owner_kind TEXT NOT NULL,
              owner_id TEXT NOT NULL
          );

          CREATE TABLE items (
              id TEXT PRIMARY KEY NOT NULL,
              parent_kind TEXT NOT NULL,
              parent_id TEXT NOT NULL,
              order_key INTEGER NOT NULL,
              kind TEXT NOT NULL,
              tab_id TEXT,
              custom_title TEXT
          );

          CREATE TABLE tabs (
              id TEXT PRIMARY KEY NOT NULL,
              profile_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
              current_url TEXT,
              saved_url TEXT,
              page_title TEXT,
              last_active_at REAL NOT NULL,
              created_at REAL NOT NULL,
              owner_kind TEXT NOT NULL,
              owner_id TEXT NOT NULL
          );

          CREATE TABLE split_configurations (
              item_id TEXT PRIMARY KEY NOT NULL REFERENCES items(id) ON DELETE CASCADE,
              orientation TEXT NOT NULL,
              weights_json TEXT NOT NULL,
              focused_child_item_id TEXT NOT NULL
          );

          CREATE TABLE window_sessions (
              id TEXT PRIMARY KEY NOT NULL,
              kind TEXT NOT NULL,
              selected_space_id TEXT,
              selected_item_id TEXT,
              selected_pane_id TEXT,
              sidebar_visible INTEGER NOT NULL,
              sidebar_width REAL NOT NULL,
              frame_json TEXT,
              last_selections_json TEXT NOT NULL
          );

          CREATE TABLE archive_entries (
              id TEXT PRIMARY KEY NOT NULL,
              profile_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
              origin_space_id TEXT,
              origin_parent_hint_id TEXT,
              original_region TEXT NOT NULL,
              payload_version INTEGER NOT NULL,
              snapshot_json TEXT NOT NULL,
              reason TEXT NOT NULL,
              archived_at REAL NOT NULL,
              restored_at REAL
          );

          CREATE TABLE history_visits (
              id TEXT PRIMARY KEY NOT NULL,
              profile_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
              url TEXT NOT NULL,
              title TEXT,
              visited_at REAL NOT NULL
          );

          CREATE INDEX history_profile_visited
              ON history_visits(profile_id, visited_at DESC);

          CREATE TABLE route_rules (
              id TEXT PRIMARY KEY NOT NULL,
              sort_order INTEGER NOT NULL,
              enabled INTEGER NOT NULL,
              matching_style TEXT NOT NULL,
              pattern TEXT NOT NULL,
              destination_kind TEXT NOT NULL,
              destination_id TEXT NOT NULL
          );

          CREATE TABLE application_settings (
              singleton INTEGER PRIMARY KEY NOT NULL CHECK (singleton = 1),
              default_profile_id TEXT NOT NULL REFERENCES profiles(id),
              external_destination_kind TEXT NOT NULL,
              external_destination_id TEXT NOT NULL,
              appearance TEXT NOT NULL,
              archive_retention_seconds REAL NOT NULL,
              history_retention_seconds REAL NOT NULL
          );

          CREATE TABLE pending_operations (
              id TEXT PRIMARY KEY NOT NULL,
              kind TEXT NOT NULL,
              target_id TEXT NOT NULL,
              store_id TEXT,
              phase TEXT NOT NULL,
              last_error TEXT,
              attempt_at REAL NOT NULL
          );

          CREATE TABLE processed_open_requests (
              request_id TEXT PRIMARY KEY NOT NULL,
              processed_at REAL NOT NULL
          );

          INSERT INTO meta(key, value) VALUES ('revision', '0');
          """)
      }
    ]
  }

  static var currentVersion: Int32 {
    production().last?.version ?? 0
  }
}
