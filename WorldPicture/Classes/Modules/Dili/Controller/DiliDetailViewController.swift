//
//  DetailViewController.swift
//  WorldPicture
//
//  Created by Chaosky on 2016/11/15.
//  Copyright © 2016年 ChaosVoid. All rights reserved.
//

import UIKit
import Alamofire
import MBProgressHUD
import SnapKit

class DiliDetailViewController: UIViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {

    var albumID: String!
    
    var pictureListModel: PictureListModel!
    
    var currentIndex = 0
    
    @IBOutlet weak var picNameLabel: UILabel!
    
    @IBOutlet weak var picIndexLabel: UILabel!
    
    @IBOutlet weak var contentView: UIView!
    @IBOutlet var showOrHideViews: [UIView]!
    
    @IBOutlet weak var bottomView: UIView!
    
    private let picContentView = UITextView()
    
    var pageViewController: UIPageViewController!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        setupViews()
        requestAlbumDetail()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    func setupViews() {
        
        contentView.backgroundColor = .clear
        
        picContentView.backgroundColor = .clear
        picContentView.isEditable = false
        picContentView.textColor = .white
        picContentView.font = .systemFont(ofSize: 14)
        contentView.addSubview(picContentView)
        
        picContentView.snp.makeConstraints { (maker) in
            maker.edges.equalToSuperview()
        }
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(onTap))
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc private func onTap() {
        showOrHideViewsTapped()
    }
    
    func initialPageViewController() {
        
        if pageViewController == nil {
            pageViewController = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
            pageViewController.dataSource = self
            pageViewController.delegate = self
            addChild(pageViewController)
            view.addSubview(pageViewController.view)
            pageViewController.view.snp.makeConstraints { (maker) in
                maker.edges.equalTo(view)
            }
            view.sendSubviewToBack(pageViewController.view)
        }
        
        let initPictureDetail = createPictureDetail()
        initPictureDetail.pictureModel = pictureListModel.picture![0]
        pageViewController.setViewControllers([initPictureDetail], direction: .forward, animated: false, completion: nil)
        currentIndex = 0
    }
    
    func showOrHideViewsTapped() {
        UIView.animate(withDuration: 0.5, animations: {
            for view in self.showOrHideViews {
                view.alpha = view.alpha == 0 ? 1 : 0;
            }
        })
    }
    
    func requestAlbumDetail() {
        let hud = MBProgressHUD.showAdded(to: view, animated: true)
        hud.mode = .indeterminate
        
        APIProvider.request(DiliAPI.albums(albumId: albumID).multiTarget) { result in
            switch result {
            case let .success(response):
                guard let model = PictureListModel.yy_model(withJSON: response.data) else {
                    hud.hide(animated: true)
                    return
                }
                self.pictureListModel = model
                DispatchQueue.main.async {
                    self.initialPageViewController()
                    self.updateViews()
                    hud.hide(animated: true)
                }
            case let .failure(error):
                hud.mode = .text
                hud.label.text = "加载失败"
                hud.detailsLabel.text = "错误描述：\(error.localizedDescription)"
                hud.hide(animated: true, afterDelay: 1)
                self.bottomView.isUserInteractionEnabled = false
            }
        }
    }
    
    func createPictureDetail() -> PictureDetailViewController {
        let pictureDetail = StoryboardScene.Dili.pictureDetailViewController.instantiate()
        return pictureDetail
    }
    
    func updateViews() {
        
        if let count = pictureListModel?.counttotal {
            picIndexLabel.text = "\(currentIndex+1)/\(count)"
        }
        
        if let currentPic = pictureListModel?.picture?[currentIndex] {
            picNameLabel.text = currentPic.title
            picContentView.text = "\(currentPic.content!)（摄像：\(currentPic.author!)）"
            picContentView.scrollToTop()
        }
    }
    
    func nextViewController(_ viewController: PictureDetailViewController, before: Bool) -> PictureDetailViewController? {
        if let index = pictureListModel.picture?.firstIndex(of: viewController.pictureModel!) {
            let nextIndex = before ? index - 1 : index + 1
            if nextIndex < 0 || nextIndex >= (pictureListModel.picture?.count)! {
                return nil
            }
            else {
                let detailVC = createPictureDetail()
                detailVC.pictureModel = pictureListModel.picture?[nextIndex]
                return detailVC
            }
        }
        else {
            return nil
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func shareTapped(_ sender: UIButton) {
        guard let content = pictureListModel?.picture?[currentIndex].content else {
            return
        }
        guard let currentPictureDetail = pageViewController.viewControllers?.first as? PictureDetailViewController else {
            return
        }
        if let image = currentPictureDetail.imageView.image {
            if !image.isEqual(Asset.Assets.Dili.nopic.image) {
                let activityVC = UIActivityViewController(activityItems: [image, content], applicationActivities: nil)
                activityVC.popoverPresentationController?.sourceView = sender
                present(activityVC, animated: true, completion: nil)
            }
        }
    }
    
    @IBAction func saveTapped(_ sender: UIButton) {
        guard let currentPictureDetail = pageViewController.viewControllers?.first as? PictureDetailViewController else {
            return
        }
        
        if let image = currentPictureDetail.imageView.image {
            if !image.isEqual(Asset.Assets.Dili.nopic.image) {
                Utils.writeImageToPhotosAlbum(image)
            }
        }
    }
    
    @IBAction func backTapped(_ sender: UIButton) {
        _ = navigationController?.popViewController(animated: true)
        dismiss(animated: true, completion: nil)
        
    }
    
    // MARK: - UIPageViewControllerDataSource
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        return nextViewController(viewController as! PictureDetailViewController, before: true)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        return nextViewController(viewController as! PictureDetailViewController, before: false)
    }
    
    // MARK: - UIPageViewControllerDelegate
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if let visiableVC = pageViewController.viewControllers?.first as? PictureDetailViewController {
            currentIndex = (pictureListModel.picture?.firstIndex(of: visiableVC.pictureModel))!
            updateViews()
        }
    }

}
