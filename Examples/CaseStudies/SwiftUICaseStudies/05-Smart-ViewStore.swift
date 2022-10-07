//
//  05-Smart-ViewStore.swift
//  SwiftUICaseStudies
//
//  Created by Fabian Sturm on 07.10.22.
//  Copyright © 2022 Point-Free. All rights reserved.
//

import ComposableArchitecture
import SwiftUI

public struct SmartViewStore: ReducerProtocol {
  public enum Action: Equatable {
    case updateA(String)
    case updateB(String)
    case updateC(String)
  }
  
  public struct State: Equatable {
    var a: String = "A"
    var b: String = "B"
    var c: String = "C"
  }
  
  public var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .updateA(let newValue):
        state.a = newValue
      case .updateB(let newValue):
        state.b = newValue
      case .updateC(let newValue):
        state.c = newValue
      }
      print("Updated state")
      return .none
    }
//    .debug()
  }
  
  public static var example: StoreOf<Self> {
    return .init(initialState: exampleState, reducer: Self())
  }
  
  public static var exampleState: State {
    return State()
  }
}


public struct SmartViewStoreView: View {
  private let store: StoreOf<SmartViewStore>
  
  public init(store: StoreOf<SmartViewStore>) {
    self.store = store
  }
  
  public var body: some View {
    WithViewStore(store) { viewStore in
      let x = print("rerendering!")
      
      Text(viewStore.a)
      Text(viewStore.b)
      
      Button("Update A", action: {
        let rand = Int.random(in: 0...999)
        viewStore.send(.updateA(String(describing: rand)))
        _ = x
      })
      
      Button("Update B", action: {
        let rand = Int.random(in: 0...999)
        viewStore.send(.updateB(String(describing: rand)))
      })
      
      Button("Update C", action: {
        let rand = Int.random(in: 0...999)
        viewStore.send(.updateC(String(describing: rand)))
      })
    }
  }
}

