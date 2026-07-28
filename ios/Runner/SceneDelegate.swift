import UIKit

import Flutter

import HealthKit

import FBSDKCoreKit

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

    if let url = connectionOptions.urlContexts.first?.url {
      ApplicationDelegate.shared.application(
        UIApplication.shared,
        open: url,
        sourceApplication: nil,
        annotation: [UIApplication.OpenURLOptionsKey.annotation]
      )
    }

  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    if let url = URLContexts.first?.url {
      ApplicationDelegate.shared.application(
        UIApplication.shared,
        open: url,
        sourceApplication: nil,
        annotation: [UIApplication.OpenURLOptionsKey.annotation]
      )
    }
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

    var sleepOrigins: [String] = []

    var stepOrigins: [String] = []

    var exerciseOrigins: [String] = []

    var firstErrorMessage: String?

    let resultLock = NSLock()

    let now = Date()

    let calendar = Calendar.current

    let startOfDay = calendar.startOfDay(for: now)

    let sleepStart = calendar.date(byAdding: .hour, value: -12, to: startOfDay) ?? startOfDay

    let localDate = localDateString(now)

    group.enter()

    fetchTodaySteps(from: startOfDay, to: now) { value, origins, error in

      print("fetchTodaySteps callback, value: \(value), error: \(String(describing: error))")

      resultLock.lock()
      steps = value
      stepOrigins = origins

      if let error = error, firstErrorMessage == nil {

        firstErrorMessage = error.localizedDescription

      }
      resultLock.unlock()

      group.leave()

    }

    group.enter()

    fetchSleepHours(from: sleepStart, to: now) { value, origins, error in

      print("fetchLastNightSleepHours callback, value: \(value), error: \(String(describing: error))")

      resultLock.lock()
      sleepHours = value
      sleepOrigins = origins

      if let error = error, firstErrorMessage == nil {

        firstErrorMessage = error.localizedDescription

      }
      resultLock.unlock()

      group.leave()

    }

    group.enter()

    fetchTodayExerciseMinutes(from: startOfDay, to: now) { value, origins, error in

      print("fetchTodayExerciseMinutes callback, value: \(value), error: \(String(describing: error))")

      resultLock.lock()
      exerciseMinutes = value
      exerciseOrigins = origins

      if let error = error, firstErrorMessage == nil {

        firstErrorMessage = error.localizedDescription

      }
      resultLock.unlock()

      group.leave()

    }

    group.notify(queue: .main) {

      print("getHealthData returning result")

      result([

        "success": firstErrorMessage == nil,

        "message": firstErrorMessage ?? "已成功同步 Apple 健康資料",

        "sleepHours": sleepHours,

        "steps": steps,

        "exerciseMinutes": exerciseMinutes,

        "snapshots": [
          self.healthSnapshot(
            activityType: "steps",
            metricValue: Double(steps),
            metricUnit: "steps",
            localDate: localDate,
            periodStart: startOfDay,
            periodEnd: now,
            observedAt: now,
            dataOrigins: stepOrigins
          ),
          self.healthSnapshot(
            activityType: "sleep",
            metricValue: sleepHours,
            metricUnit: "hours",
            localDate: localDate,
            periodStart: sleepStart,
            periodEnd: now,
            observedAt: now,
            dataOrigins: sleepOrigins
          ),
          self.healthSnapshot(
            activityType: "exercise",
            metricValue: Double(exerciseMinutes),
            metricUnit: "minutes",
            localDate: localDate,
            periodStart: startOfDay,
            periodEnd: now,
            observedAt: now,
            dataOrigins: exerciseOrigins
          )
        ]

      ])

    }

  }

  private func fetchTodaySteps(
    from start: Date,
    to end: Date,
    completion: @escaping (Int, [String], Error?) -> Void
  ) {

    guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {

      completion(0, [], nil)

      return

    }

    let predicate = HKQuery.predicateForSamples(

      withStart: start,

      end: end,

      options: .strictStartDate

    )

    let query = HKStatisticsQuery(

      quantityType: stepType,

      quantitySamplePredicate: predicate,

      options: [.cumulativeSum, .separateBySource]

    ) { _, statistics, error in

      let value = statistics?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0

      let origins = statistics?.sources
        .map(\.bundleIdentifier)
        .sorted() ?? []

      completion(Int(value), origins, error)

    }

    healthStore.execute(query)

  }

  private func fetchTodayExerciseMinutes(
    from start: Date,
    to end: Date,
    completion: @escaping (Int, [String], Error?) -> Void
  ) {

    guard let exerciseType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) else {

      completion(0, [], nil)

      return

    }

    let predicate = HKQuery.predicateForSamples(

      withStart: start,

      end: end,

      options: .strictStartDate

    )

    let query = HKStatisticsQuery(

      quantityType: exerciseType,

      quantitySamplePredicate: predicate,

      options: [.cumulativeSum, .separateBySource]

    ) { _, statistics, error in

      let value = statistics?.sumQuantity()?.doubleValue(for: HKUnit.minute()) ?? 0

      let origins = statistics?.sources
        .map(\.bundleIdentifier)
        .sorted() ?? []

      completion(Int(value), origins, error)

    }

    healthStore.execute(query)

  }

  private func fetchSleepHours(
    from start: Date,
    to end: Date,
    completion: @escaping (Double, [String], Error?) -> Void
  ) {

    guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {

      completion(0, [], nil)

      return

    }

    let predicate = HKQuery.predicateForSamples(

      withStart: start,

      end: end,

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

        completion(0, [], error)

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

      var intervals: [DateInterval] = []

      var origins: Set<String> = []

      for sample in samples {

        if asleepValues.contains(sample.value) {

          let clippedStart = max(sample.startDate, start)

          let clippedEnd = min(sample.endDate, end)

          if clippedEnd > clippedStart {

            intervals.append(DateInterval(start: clippedStart, end: clippedEnd))

            origins.insert(sample.sourceRevision.source.bundleIdentifier)

          }

        }

      }

      let sortedIntervals = intervals.sorted { $0.start < $1.start }

      var mergedIntervals: [DateInterval] = []

      for interval in sortedIntervals {

        if let last = mergedIntervals.last, interval.start <= last.end {

          mergedIntervals[mergedIntervals.count - 1] = DateInterval(
            start: last.start,
            end: max(last.end, interval.end)
          )

        } else {

          mergedIntervals.append(interval)

        }

      }

      let totalSeconds = mergedIntervals.reduce(0) { total, interval in

        total + interval.duration

      }

      completion(totalSeconds / 3600.0, origins.sorted(), nil)

    }

    healthStore.execute(query)

  }

  private func healthSnapshot(
    activityType: String,
    metricValue: Double,
    metricUnit: String,
    localDate: String,
    periodStart: Date,
    periodEnd: Date,
    observedAt: Date,
    dataOrigins: [String]
  ) -> [String: Any] {
    return [
      "activityType": activityType,
      "metricValue": metricValue,
      "metricUnit": metricUnit,
      "localDate": localDate,
      "periodStart": isoTimestamp(periodStart),
      "periodEnd": isoTimestamp(periodEnd),
      "observedAt": isoTimestamp(observedAt),
      "dataOrigins": dataOrigins
    ]
  }

  private func isoTimestamp(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
  }

  private func localDateString(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar.current
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }

}
