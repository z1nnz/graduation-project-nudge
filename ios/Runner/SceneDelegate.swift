import UIKit

import Flutter

import HealthKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

  var window: UIWindow?

  private let healthStore = HKHealthStore()

  private let channelName = "nudge/healthkit"

  func scene(

    _ scene: UIScene,

    willConnectTo session: UISceneSession,

    options connectionOptions: UIScene.ConnectionOptions

  ) {

    guard let windowScene = scene as? UIWindowScene else { return }

    // 使用 Main.storyboard 原本的 FlutterViewController

    if window == nil {

      let storyboard = UIStoryboard(name: "Main", bundle: nil)

      let window = UIWindow(windowScene: windowScene)

      window.rootViewController = storyboard.instantiateInitialViewController()

      self.window = window

      window.makeKeyAndVisible()

    }

    guard let controller = window?.rootViewController as? FlutterViewController else {

      print("SceneDelegate: rootViewController is not FlutterViewController")

      return

    }

    setupHealthChannel(on: controller)

  }

  private func setupHealthChannel(on controller: FlutterViewController) {

    let channel = FlutterMethodChannel(

      name: channelName,

      binaryMessenger: controller.binaryMessenger

    )

    channel.setMethodCallHandler { [weak self] call, result in

      guard let self = self else {

        result(FlutterError(code: "UNAVAILABLE", message: "SceneDelegate unavailable", details: nil))

        return

      }

      switch call.method {

      case "requestHealthAuthorization":

        self.requestHealthAuthorization(result: result)

      case "getHealthData":

        self.getHealthData(result: result)

      default:

        result(FlutterMethodNotImplemented)

      }

    }

  }

  private func requestHealthAuthorization(result: @escaping FlutterResult) {

    guard HKHealthStore.isHealthDataAvailable() else {

      result(false)

      return

    }

    guard

      let stepType = HKObjectType.quantityType(forIdentifier: .stepCount),

      let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),

      let exerciseType = HKObjectType.quantityType(forIdentifier: .appleExerciseTime)

    else {

      result(false)

      return

    }

    let readTypes: Set<HKObjectType> = [stepType, sleepType, exerciseType]

    healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, error in

      DispatchQueue.main.async {

        if let error = error {

          print("Health authorization error: \(error.localizedDescription)")

        }

        result(success)

      }

    }

  }

  private func getHealthData(result: @escaping FlutterResult) {

    print("getHealthData called")

    guard HKHealthStore.isHealthDataAvailable() else {

      result([

        "success": false,

        "message": "HealthKit unavailable",

        "sleepHours": 0.0,

        "steps": 0,

        "exerciseMinutes": 0

      ])

      return

    }

    let group = DispatchGroup()

    var sleepHours: Double = 0

    var steps: Int = 0

    var exerciseMinutes: Int = 0

    var firstErrorMessage: String?

    group.enter()

    fetchTodaySteps { value, error in

      print("fetchTodaySteps callback, value: \(value), error: \(String(describing: error))")

      steps = value

      if let error = error, firstErrorMessage == nil {

        firstErrorMessage = error.localizedDescription

      }

      group.leave()

    }

    group.enter()

    fetchLastNightSleepHours { value, error in

      print("fetchLastNightSleepHours callback, value: \(value), error: \(String(describing: error))")

      sleepHours = value

      if let error = error, firstErrorMessage == nil {

        firstErrorMessage = error.localizedDescription

      }

      group.leave()

    }

    group.enter()

    fetchTodayExerciseMinutes { value, error in

      print("fetchTodayExerciseMinutes callback, value: \(value), error: \(String(describing: error))")

      exerciseMinutes = value

      if let error = error, firstErrorMessage == nil {

        firstErrorMessage = error.localizedDescription

      }

      group.leave()

    }

    group.notify(queue: .main) {

      print("getHealthData returning result")

      result([

        "success": firstErrorMessage == nil,

        "message": firstErrorMessage ?? "已成功同步 Apple 健康資料",

        "sleepHours": sleepHours,

        "steps": steps,

        "exerciseMinutes": exerciseMinutes

      ])

    }

  }

  private func fetchTodaySteps(completion: @escaping (Int, Error?) -> Void) {

    guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {

      completion(0, nil)

      return

    }

    let now = Date()

    let startOfDay = Calendar.current.startOfDay(for: now)

    let predicate = HKQuery.predicateForSamples(

      withStart: startOfDay,

      end: now,

      options: .strictStartDate

    )

    let query = HKStatisticsQuery(

      quantityType: stepType,

      quantitySamplePredicate: predicate,

      options: .cumulativeSum

    ) { _, statistics, error in

      let value = statistics?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0

      completion(Int(value), error)

    }

    healthStore.execute(query)

  }

  private func fetchTodayExerciseMinutes(completion: @escaping (Int, Error?) -> Void) {

    guard let exerciseType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) else {

      completion(0, nil)

      return

    }

    let now = Date()

    let startOfDay = Calendar.current.startOfDay(for: now)

    let predicate = HKQuery.predicateForSamples(

      withStart: startOfDay,

      end: now,

      options: .strictStartDate

    )

    let query = HKStatisticsQuery(

      quantityType: exerciseType,

      quantitySamplePredicate: predicate,

      options: .cumulativeSum

    ) { _, statistics, error in

      let value = statistics?.sumQuantity()?.doubleValue(for: HKUnit.minute()) ?? 0

      completion(Int(value), error)

    }

    healthStore.execute(query)

  }

  private func fetchLastNightSleepHours(completion: @escaping (Double, Error?) -> Void) {

    guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {

      completion(0, nil)

      return

    }

    let now = Date()

    let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now

    let predicate = HKQuery.predicateForSamples(

      withStart: sevenDaysAgo,

      end: now,

      options: .strictStartDate

    )

    let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

    let query = HKSampleQuery(

      sampleType: sleepType,

      predicate: predicate,

      limit: HKObjectQueryNoLimit,

      sortDescriptors: [sortDescriptor]

    ) { _, samples, error in

      guard let samples = samples as? [HKCategorySample], error == nil else {

        completion(0, error)

        return

      }

      var asleepValues: Set<Int> = [

        HKCategoryValueSleepAnalysis.asleep.rawValue

      ]

      if #available(iOS 16.0, *) {

        asleepValues.insert(HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue)

        asleepValues.insert(HKCategoryValueSleepAnalysis.asleepCore.rawValue)

        asleepValues.insert(HKCategoryValueSleepAnalysis.asleepDeep.rawValue)

        asleepValues.insert(HKCategoryValueSleepAnalysis.asleepREM.rawValue)

      }

      let calendar = Calendar.current

      let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now

      let targetDay = calendar.startOfDay(for: yesterday)

      var totalSeconds: TimeInterval = 0

      for sample in samples {

        if asleepValues.contains(sample.value) {

          let sampleDay = calendar.startOfDay(for: sample.endDate)

          if sampleDay == targetDay || calendar.startOfDay(for: sample.startDate) == targetDay {

            totalSeconds += sample.endDate.timeIntervalSince(sample.startDate)

          }

        }

      }

      completion(totalSeconds / 3600.0, nil)

    }

    healthStore.execute(query)

  }

}
