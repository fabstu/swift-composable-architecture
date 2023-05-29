import SwiftUI

public class TCASettings {
  var enableWithViewStoreRerenderLogging: RendererLogging?
  // Hide initial state diffs
  // a) per location (prefix, file, line)?
  //    -> easy to implement.
  // b) for all .tcaSettings invocations?
  //    -> WithViewStore only has the data from its settings.
  //    -> unintuitive.
  //
  // Decision: Use a).
  var initialStateHideDiffs: Bool
  
  public enum RendererLogging {
    case raw
    case statistics
  }

  fileprivate init(
    enableWithViewStoreRerenderLogging: RendererLogging? = nil,
    initialStateHideDiffs: Bool = true
  ) {
    self.enableWithViewStoreRerenderLogging = enableWithViewStoreRerenderLogging
    self.initialStateHideDiffs = initialStateHideDiffs
  }

  public init(
    _ builder: Builder
  ) {
    self.enableWithViewStoreRerenderLogging = builder.settings.enableWithViewStoreRerenderLogging
    self.initialStateHideDiffs = builder.settings.initialStateHideDiffs
  }

  static var settings = TCASettings()

  public class Builder {
    fileprivate var settings: TCASettings

    private init(settings: TCASettings) {
      self.settings = settings
    }

    public func withRerenderLogging(_ loggingType: RendererLogging) -> Builder {
      settings.enableWithViewStoreRerenderLogging = loggingType
      return self
    }

    public static func withRerenderLogging(_ loggingType: RendererLogging) -> Builder {
      return Builder(settings: .init())
        .withRerenderLogging(loggingType)
    }
    
    public func withInitialStateHideDiffs(_ value: Bool) -> Builder {
      settings.initialStateHideDiffs = value
      return self
    }
  }
}

private struct TCASettingsEnvironmentKey: EnvironmentKey {
  // this is the default value that SwiftUI will fallback to if you don't pass the object
  public static var defaultValue: TCASettings = .init()
}

extension EnvironmentValues {
  // the new key path to access your object (\.object)
  var tcaSettings: TCASettings {
    get { self[TCASettingsEnvironmentKey.self] }
    set { self[TCASettingsEnvironmentKey.self] = newValue }
  }
}

// Options:
//
// 1) Each .tcaSettings call runs its own renderer
// 2) Each .tcaSettings call-site pools its own renderer.
// 3) Only one renderer overall that prints statistics together.
//
// a) .tcaSettings renderers print every statistic.
//    A? No issue, because the relevant settings passed with @Environment are available and used in WithViewStore with highest priority.
//    B? Have to deal with race conditions incase multiple renderers.
//    C? Not an issue.
// b) .tcaSettings renderers print the statistics from the call-site
//    A? Have to know what call-site it is and split up the statistics per-callsite. Have to start-up when at least one is available and
//       shut the worker down when all .tcaSettings are hidden/not visible anymore.
//    B? When its different call-sites, just handled by different renderer. When its same call-site, rendered by same renderer. No conflicts.
//    C? Not an issue.
// c) .tcaSettings renderers print the statistics from their own .tcaSettings call.
//    B? Not a problem.
//    C? An issue.
//
// Complexity:
//
// A) Recursive .tcaSettings enabling and disabling statistics-taking. Not an issue either way, just disables for child-views.
// B) Recursive .tcaSettings for the same WithViewStore-statistics.
// C) Not losing track after re-render.
//
// Result:
// Use single pooled renderer that is available as long as at least 1 .tcaSettings.task block is active.

public extension View {
  func tcaSettings(_ builder: TCASettings.Builder, file: StaticString = #fileID, line: UInt = #line) -> some View {
    ZStack {
      if #available(iOS 15.0, *), #available(macOS 12.0, *) {
        environment(\.tcaSettings, builder.settings)
          .task {
            if builder.settings.enableWithViewStoreRerenderLogging == .statistics {
              await RenderedStatistics.watchAndPrintCounts()
            }
          }
      } else {
        environment(\.tcaSettings, builder.settings)
      }
    }
  }
}

