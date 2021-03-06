/*
 Copyright (c) 2015, Apple Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 
 1.  Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2.  Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation and/or
 other materials provided with the distribution.
 
 3.  Neither the name of the copyright holder(s) nor the names of any contributors
 may be used to endorse or promote products derived from this software without
 specific prior written permission. No license is granted to the trademarks of
 the copyright holders even if such marks are included in this software.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import UIKit
import ResearchKit
import AWSS3

let loginUUID = UUID()

class OnboardingViewController: UIViewController {
  @IBAction func joinAction(_ sender: Any) {
    let taskViewController = ORKTaskViewController(task: Onboarding.onboardingSurvey, taskRun: nil)
    taskViewController.delegate = self
    present(taskViewController, animated: true, completion: nil)
  }
  @IBAction func alreadyAUser(_ sender: Any) {
    let taskViewController = ORKTaskViewController(task: LoginStep.loginTask, taskRun: loginUUID)
    taskViewController.delegate = self
    present(taskViewController, animated: true, completion: nil)
  }
}



extension OnboardingViewController: ORKTaskViewControllerDelegate {
  public func taskViewController(_ taskViewController: ORKTaskViewController, didFinishWith reason: ORKTaskViewControllerFinishReason, error: Error?) {
    switch reason {
    case .completed:
      if taskViewController.taskRunUUID == loginUUID {
        performSegue(withIdentifier: "unwindToStudy", sender: nil)
        break
      }
      let deviceID = UIDevice.current.identifierForVendor!.uuidString
      UserDefaults.standard.set(deviceID, forKey: "User UUID")
      if ORKPasscodeViewController.isPasscodeStoredInKeychain() == true {
        submitUserConsent(taskViewController: taskViewController)
        let taskResults = TaskViewControllerResults.getViewControllerResults(taskViewController: taskViewController)
        
        ProcessResults.saveResults(taskResults: taskResults, uuid: taskViewController.taskRunUUID)
        performSegue(withIdentifier: "unwindToStudy", sender: nil)
      } else {
        dismiss(animated: true, completion: nil)
      }
    case .discarded, .failed, .saved:
      dismiss(animated: true, completion: nil)
    }
  }
  
  private func submitUserConsent(taskViewController: ORKTaskViewController) {
    var completionHandler: AWSS3TransferUtilityUploadCompletionHandlerBlock?
    let consentDocument = ConsentDocument()
    let result = taskViewController.result
    if let consentStepResult = result.stepResult(forStepIdentifier: "ConsentReviewStep"),
      let signatureResult = consentStepResult.results?.first as? ORKConsentSignatureResult {
      signatureResult.apply(to: consentDocument)
      consentDocument.makePDF(completionHandler: { (data, error) -> Void in
        let tempPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
        let path = tempPath.strings(byAppendingPaths: ["consent.pdf"])
        let pathString = path.joined()
        var betterPathString = "file://"
        betterPathString += pathString
        let pathURL = URL(string: betterPathString)
        do {
          try data?.write(to: pathURL!)
        } catch {
          print(error)
        }
        let pdf = (FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)).last
        let consentPDF = pdf?.appendingPathComponent("consent.pdf")
        let transferUtility = AWSS3TransferUtility.default()
        let expression = AWSS3TransferUtilityUploadExpression()
        expression.setValue("AES256", forRequestParameter: "x-amz-server-side-encryption")
        let uuidString = UUID().uuidString
        transferUtility.uploadFile(consentPDF!, bucket: "iosappbucket", key: "Participant_Consent/Participant_Consent_\(uuidString).pdf", contentType: "consent/pdf", expression: expression, completionHandler: completionHandler).continueWith { (task) -> AnyObject! in
          if let error = task.error {
            print(error.localizedDescription)
            
          }
          if let _ = task.result {
            print("uploading started")
          }
          return nil
          
        }
      })
    }
  }//end submitUserConsent
}

