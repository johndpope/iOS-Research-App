//
//  ResultSave.swift
//  Breast Feeding NFP
//
//  Created by Anthony Schneider on 9/14/17.
//  Copyright © 2017 Anthony Schneider. All rights reserved.
//

import Foundation
import AWSS3


class ProcessResults {
  private var results: TaskResults!
  private let date: Date
  private var uuid: UUID
  private var surveyType: String!
  static private var processResults: ProcessResults!
  
  var completionHandler: AWSS3TransferUtilityUploadCompletionHandlerBlock?
  let transferUtility = AWSS3TransferUtility.default()

  private init(taskResults: TaskResults!, uuid: UUID!) {
    if let results = taskResults as? CycleTaskResults {
      self.results = results
      self.surveyType = "CycleTask"
    }
    if let results = taskResults as? OnboardingTaskResults {
      self.results = results
      self.surveyType = "Onboarding"
    }
    if let results = taskResults as? BreastFeedingTaskResults {
      self.results = results
      self.surveyType = "BreastFeedingDateTime"
    }
    self.uuid = uuid
    self.date = Date()
  }
  
  static func saveResults(taskResults: TaskResults!, uuid: UUID!) {
    processResults = ProcessResults(taskResults: taskResults, uuid: uuid)
    let fileName = processResults.surveyType + "_" + String(describing: Date()).replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "+", with: "").replacingOccurrences(of: ":", with: "-") + String(describing: processResults.uuid).replacingOccurrences(of: "+", with: "") + ".csv"
    let path = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
    
    do {
      try processResults.results.getEntryString().write(to: path!, atomically: true, encoding: String.Encoding.utf8)
    } catch {
      print(error.localizedDescription)
    }
    processResults.uploadResults(path: path! as NSURL, fileName: fileName)
  }
  
  func uploadResults(path: NSURL, fileName: String) {
 
    let expression = AWSS3TransferUtilityUploadExpression()

    expression.setValue("AES256", forRequestParameter: "x-amz-server-side-encryption")
    
    transferUtility.uploadFile(path as URL, bucket: "iosappbucket", key: ProcessResults.getUserUUID() + "/" + surveyType + "/" + fileName, contentType: "file/csv", expression: expression, completionHandler: completionHandler).continueWith { (task) -> AnyObject! in
      if let error = task.error {
        print(error.localizedDescription)
      }
      if let _ = task.result {
        print("uploading started")
      }
      return nil;
    }
  }
  
  private static func getUserUUID() -> String {
    if let userUUID = UserDefaults.standard.object(forKey: "User UUID") {
      if let userUUIDString = userUUID as? String {
        return userUUIDString
      }
    }
    return ""
  }
}

