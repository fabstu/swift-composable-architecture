//
//  File.swift
//  
//
//  Created by Fabian Sturm on 07.10.22.
//

import Foundation

public struct AnyEquatable {
  private let value: Any
  private let equals: (Any) -> Bool
  
  public init<T: Equatable>(_ value: T) {
    self.value = value
    self.equals = { ($0 as? T == value) }
  }
}

extension AnyEquatable: Equatable {
  static public func ==(lhs: AnyEquatable, rhs: AnyEquatable) -> Bool {
    return lhs.equals(rhs.value)
  }
}

