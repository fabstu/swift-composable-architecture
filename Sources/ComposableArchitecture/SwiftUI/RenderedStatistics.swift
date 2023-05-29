//
//  File.swift
//
//
//  Created by Fabian Sturm on 28.11.22.
//

import OrderedCollections
import SwiftUI
import os

public class RenderedStatistics {
  static let logger = os.Logger(subsystem: Bundle.main.bundleIdentifier!, category: #fileID)

  static var cache: RenderedStatistics = .init()

  private var counters: OrderedDictionary<Key, Value>
  private let countersLock = NSLock()

  init() {
    self.counters = [:]
  }

  public static func watchAndPrintCounts() async {
    await PrinterRunner.watchAndPrintCounts()
  }

  public static func add(
    prefix: String,
    file: StaticString,
    line: UInt,
    viewStateType: String,
    viewActionType: String,
    difference: String,
    isInitialStateDiff: Bool,
    hideInitialStateDiffs: Bool
  ) {
    cache.add(
      prefix: prefix,
      file: file,
      line: line,
      viewStateType: viewStateType,
      viewActionType: viewActionType,
      difference: difference,
      isInitialStateDiff: isInitialStateDiff,
      hideInitialStateDiffs: hideInitialStateDiffs
    )
  }

  fileprivate func resetCounters() {
    countersLock.withLock {
      self.counters.removeAll()
    }
  }

  fileprivate struct Key: Equatable, Hashable {
    let prefix: String
    let file: String
    let line: UInt
    let viewStateType: String
    let viewActionType: String
  }

  fileprivate struct Diff: Equatable, Hashable {
    let isInitialStateDiff: Bool
    let text: String
  }

  fileprivate struct Value {
    var differences: OrderedDictionary<Diff, Int>
    // Store this once for the location on initialization.
    let hideinitialStateDiffs: Bool
  }

  private static var differenceLineIndent = "    "

  fileprivate func printCounts() {
    countersLock.withLock {

      for (key, differencesDict) in counters {
        var overallCount = 0
        for (_, count) in differencesDict.differences {
          overallCount += count
        }

        Self.logger.log(
          """
          \n## \(overallCount, privacy: .public)x \(key.prefix, privacy: .public) \(key.file, privacy: .public)#\(key.line, privacy: .public) <\(key.viewStateType, privacy: .public), \(key.viewActionType, privacy: .public), ...>
          """
        )

        var hiddenInitialStateDiffCount = 0

        // Print diffs.
        for (difference, count) in differencesDict.differences {
          if difference.isInitialStateDiff && differencesDict.hideinitialStateDiffs {
            // Hide it.
            hiddenInitialStateDiffCount += count
            continue
          }

          let indentedDifference = difference.text.split(separator: "\n")
            .joined(separator: "\n" + Self.differenceLineIndent)

          Self.logger.log("\n## \(Self.differenceLineIndent, privacy: .public)\(count, privacy: .public)x \(indentedDifference, privacy: .public)")
        }

        if hiddenInitialStateDiffCount != 0 {
          // Print combined hidden initial state diff count.
          Self.logger.log(
            "\n## \(Self.differenceLineIndent, privacy: .public)\(hiddenInitialStateDiffCount, privacy: .public)x (Initial state) [diffs hidden]"
          )
        }
      }

    }
  }

  private func add(
    prefix: String,
    file: StaticString,
    line: UInt,
    viewStateType: String,
    viewActionType: String,
    difference: String,
    isInitialStateDiff: Bool,
    hideInitialStateDiffs: Bool
  ) {
    countersLock.withLock {

      let key = Key(
        prefix: prefix,
        file: String(describing: file),
        line: line,
        viewStateType: viewStateType,
        viewActionType: viewActionType
      )
      let diff = Diff(isInitialStateDiff: isInitialStateDiff, text: difference)

      if var value = counters[key] {
        if let counter = value.differences[diff] {
          value.differences[diff] = counter + 1
        }
        else {
          value.differences[diff] = 1
        }

        counters[key] = value
      }
      else {
        counters[key] = .init(
          differences: .init(uniqueKeysWithValues: [(diff, 1)]),
          hideinitialStateDiffs: hideInitialStateDiffs
        )
      }

    }
  }

  fileprivate static var watcherIsRunning: Bool {
    return PrinterRunner.watcherIsRunning
  }
}

private class PrinterRunner {
  private static let lock = NSLock()
  private static var watcherCount: Int = 0
  private static var runningCounter: Int = 0
  private static var nsecSleepingBetweenPrints: UInt64 = NSEC_PER_SEC * 1

  static var watcherIsRunning: Bool {
    return lock.withLock {
      return watcherCount != 0
    }
  }

  // Starts a Task when none was running. When counter drops to 0 or when too many Tasks are running, one Task stops.
  static func watchAndPrintCounts() async {
    lock.withLock {

      defer {
        watcherCount += 1
        //        print("WatcherCount: \(watcherCount)")
      }

      // Start thread if there is none before..
      guard runningCounter < 1 else {
        return
      }

      runningCounter += 1
      //      print("RunningCounter: \(runningCounter)")

      Task<(), Never> {
        do {
          while true {
            try await Task.sleep(nanoseconds: nsecSleepingBetweenPrints)

            RenderedStatistics.cache.printCounts()
            RenderedStatistics.cache.resetCounters()

            var shouldStop = false

            lock.withLock {
              if watcherCount == 0 || runningCounter > 1 {
                shouldStop = true
                // Signal to other runners/.tcaSettings watchers that we will stop.
                //
                // Avoids a race from here to shouldStop, where the counter gets increase while the Task is still running,
                // making this one stop and no other start.
                runningCounter -= 1
                //                print("RunningCounter: \(runningCounter)")
              }
            }

            if shouldStop {
              return
            }
          }
        }
        catch {
          // We never stop this task unless all .tcaSettings.task calls shut down, so this will shut down then.
        }
      }
    }

    try? await Task.sleep(nanoseconds: NSEC_PER_SEC * 999_999_999)

    // We got cancelled, signal that.
    lock.withLock {
      watcherCount -= 1
      //      print("WatcherCount: \(watcherCount)")
    }
  }
}
