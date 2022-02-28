//
//  ViewController.swift
//  ReceiptTracker-v2
//
//  Created by Chen Yu Hang on 21/2/22.
//

import UIKit
import Photos
import FirebaseStorage

class ViewController: UIViewController {
    @IBOutlet weak var captureButton: UIButton!
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var stackView: UIStackView!
    
    @IBOutlet weak var uiLabel: UILabel!
    @IBOutlet weak var uiIndicator: UIActivityIndicatorView!
    @IBOutlet weak var scrollView: UIScrollView!
    
    // used to store list of images uploaded
    var imageListUrl: [String] = []
    
    var storage = Storage.storage().reference()
    var cameraController: CameraController = CameraController()
    var receiptRecords: [ReceiptRecords] = []
}

extension ViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        captureButton.layer.borderWidth = 2
        captureButton.layer.borderColor = UIColor.black.cgColor
        captureButton.layer.cornerRadius = min(captureButton.frame.width, captureButton.frame.height) / 2
        
        uiLabel.isHidden = true
        uiIndicator.isHidden = true
        
        let gesture = UITapGestureRecognizer(target: self, action:  #selector (self.focusViewTapped (_:)))
        self.cameraView.addGestureRecognizer(gesture)
        
        self.cameraController.prepare{ (error) in
            
            if let error = error {
                print(error)
            }
            
            try? self.cameraController.displayPreview(on: self.cameraView)
        }
        
        NotionService.shared.setDatabaseId(databaseId: "23aa9937e0554091a7cc0bc1f8710264")
        NotionService.shared.getDatabaseInfo( completion: { (databaseObj, error) in
            print(databaseObj)
        })
        NotionService.shared.getAllReceiptRecords { receiptRecords, error, errorMessage in
            
            if let error = error, let errorMessage = errorMessage {
                debugPrint("DEBUG", "NotionService", "getAllReceiptRecords", "FAILED", error.localizedDescription, errorMessage, separator: ":")
                return
            }
            
            if let receiptRecords = receiptRecords {
                self.receiptRecords = receiptRecords
                
                for (index, receipt) in self.receiptRecords.enumerated() {
                    let url = URL(string: receipt.imageUrl)
                    let data = try? Data(contentsOf: url!)
                    self.receiptRecords[index].uiImage = UIImage(data: data!)
                }
                
            }
            
            DispatchQueue.main.async {
                for receipt in self.receiptRecords {
                    self.stackView.addArrangedSubview(self.createNewImageView(uiImage: receipt.uiImage!))
                }
            }

            

        }
    }
    
    func showLoadingTxt(show: Bool) {
        self.uiLabel.isHidden = !show
        self.uiIndicator.isHidden = !show
    }
    
    func setLoadingTxt(label: String) {
        self.uiLabel.text = label
    }
    
    func changePage(pageNo: Int) {
        let point = CGPoint(x: self.scrollView.bounds.width * CGFloat(pageNo), y: 0)
        self.scrollView.setContentOffset(point, animated: true)
    }
    
    @objc func focusViewTapped(_ sender: UITapGestureRecognizer) {
        try? self.cameraController.focusCamera(focusPoint: sender.location(in: self.cameraView))
    }
    
    @IBAction func captureButtonPressed(_ sender: UIButton) {
        
        
        self.cameraController.captureImage{ (uiImage, error) in
            if let error = error {
                print(error)
            } else if let uiImage = uiImage {
                
                DispatchQueue.main.async {
                    self.setLoadingTxt(label: "Uploading Images")
                    self.showLoadingTxt(show: true)
                }
                
                guard let imageData = uiImage.jpegData(compressionQuality: 100) else { return }
                
                var uploadInfo = FirebaseService.FirebaseImageUploadInfo()
                uploadInfo.imageName = self.randomFileName(length: 20)
                uploadInfo.parentFolderName = "images"
                uploadInfo.imageData = imageData

                FirebaseService.shared.uploadImage(firebaseImageUploadInfo: uploadInfo, completionBlock: { urlString, error in
                    guard error == nil else {
                        debugPrint("DEBUG", "UploadImage", "FAIL", error.debugDescription, separator: ":")
                        return
                    }
                    
                    debugPrint("DEBUG", "UploadImage", "SUCCESS", urlString!, separator: ":")
                    
                    // Add into the current image list url
                    self.imageListUrl.append(urlString!)
                    
                    self.insertNewReceiptRecords(imageUrl: urlString!, uiImage: uiImage)
                })
            }
        }
    }
    
    func randomFileName(length: Int) -> String {
      let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
      return String((0..<length).map{ _ in letters.randomElement()! }) + ".jpg"
    }
    
    func createNewImageView(uiImage: UIImage) -> UIImageView {
        let newImageView = UIImageView()
        newImageView.contentMode = .scaleAspectFit
        newImageView.image = uiImage
        newImageView.frame = self.cameraView.frame
        return newImageView
    }
    
    func insertNewReceiptRecords(imageUrl: String, uiImage: UIImage) {
        var receiptRecord = ReceiptRecords(id: "3", store: "No Store Specified", purchaseDate: Date(), category: "Not categorized", price: 0, imageUrl: imageUrl)
        self.receiptRecords.append(receiptRecord)
        DispatchQueue.main.async {
            self.setLoadingTxt(label: "Adding records")
        }
        
        NotionService.shared.setDatabaseId(databaseId: "23aa9937e0554091a7cc0bc1f8710264")
        
        debugPrint("DEBUG", "insertNewReceiptRecords", "started", separator: ":")
        
        NotionService.shared.createNewReceiptRecords(receiptRecords: receiptRecord) { error in
            guard error == nil else {
                debugPrint("DEBUG", "insertNewReceiptRecords", "FAIL", error.debugDescription, separator: ":")
                DispatchQueue.main.async {
                    self.showLoadingTxt(show: false)
                }
                return
            }
            
            debugPrint("DEBUG", "insertNewReceiptRecords", "SUCCESS", error.debugDescription, separator: ":")
            
            DispatchQueue.main.async {
                self.showLoadingTxt(show: false)
                self.stackView.addArrangedSubview(self.createNewImageView(uiImage: uiImage))
                self.changePage(pageNo: self.receiptRecords.count)
            }
        }
    }
}
