//
//  AccountViewController.swift
//  O3
//
//  Created by Andrei Terentiev on 9/11/17.
//  Copyright © 2017 drei. All rights reserved.
//

import Foundation
import UIKit
import NeoSwift
import DeckTransition

class AccountViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var historyTableView: UITableView!
    @IBOutlet weak var assetCollectionView: UICollectionView!
    @IBOutlet weak var claimButon: UIButton?

    var transactionHistory = [TransactionHistoryEntry]()
    var neoBalance: Int?
    var gasBalance: Double?
    var assets: Assets?
    var selectedTransactionID: String!
    var refreshClaimableGasTimer: Timer?

    func loadNeoData() {
        Neo.client.getTransactionHistory(for: Authenticated.account?.address ?? "") { result in
            switch result {
            case .failure:
                return
            case .success(let txHistory):
                self.transactionHistory = txHistory.entries
                DispatchQueue.main.async { self.historyTableView.reloadData() }
            }
        }
        Neo.client.getAccountState(for: Authenticated.account?.address ?? "") { result in
            switch result {
            case .failure:
                return
            case .success(let accountState):
                for asset in accountState.balances {
                    if asset.id.contains(NeoSwift.AssetId.neoAssetId.rawValue) {
                        self.neoBalance = Int(asset.value) ?? 0
                    } else if asset.id.contains(NeoSwift.AssetId.gasAssetId.rawValue) {
                        self.gasBalance = Double(asset.value) ?? 0
                    }
                }
                DispatchQueue.main.async {
                    self.assetCollectionView.delegate = self
                    self.assetCollectionView.dataSource = self
                    self.assetCollectionView.reloadData()
                }
            }
        }
    }

    func showClaimableGASInButton(amount: Double) {
        let gasAmountString = String(format:"%.8f", amount)
        let text = String(format:"Claim\n%@", gasAmountString)
        let attributedString = NSMutableAttributedString(string: text)

        let nsText = text as NSString
        let gasAmountRange = nsText.range(of: "\n" + gasAmountString)
        let titleRange = nsText.range(of: "Claim")
        attributedString.addAttribute(NSAttributedStringKey.foregroundColor, value: Theme.Light.grey, range: gasAmountRange)
        attributedString.addAttribute(NSAttributedStringKey.foregroundColor, value: Theme.Light.primary, range: titleRange)
        claimButon?.setAttributedTitle(attributedString, for: .normal)
    }

    @objc func loadClaimableGAS() {
        Neo.client.getClaims(address: (Authenticated.account?.address)!) { result in
            switch result {
            case .failure:
                return
            case .success(let claims):
                let amount: Double = Double(claims.totalUnspentClaim) / 100000000.0
                DispatchQueue.main.async {
                    self.showClaimableGASInButton(amount: amount)
                }
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationController?.hideHairline()
        self.navigationItem.largeTitleDisplayMode = .automatic
        historyTableView.delegate = self
        historyTableView.dataSource = self
        navigationController?.navigationBar.largeTitleTextAttributes = [NSAttributedStringKey.foregroundColor: Theme.Light.textColor,
                                                                        NSAttributedStringKey.font: UIFont(name: "Avenir-Heavy", size: 32) as Any]
        loadNeoData()
        refreshClaimableGasTimer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(AccountViewController.loadClaimableGAS), userInfo: nil, repeats: true)
        refreshClaimableGasTimer?.fire()
    }

    @IBAction func sendTapped(_ sender: Any) {
        //self.performSegue(withIdentifier: "segueToSend", sender: nil)
        let modal = UIStoryboard(name: "Send", bundle: nil).instantiateViewController(withIdentifier: "SendTableViewController")
        let nav = WalletHomeNavigationController(rootViewController: modal)
        nav.navigationBar.prefersLargeTitles = true
        nav.navigationItem.largeTitleDisplayMode = .automatic
        modal.navigationItem.leftBarButtonItem = UIBarButtonItem(image: #imageLiteral(resourceName: "times"), style: .plain, target: self, action: #selector(tappedLeftBarButtonItem(_:)))
        let transitionDelegate = DeckTransitioningDelegate()
        nav.transitioningDelegate = transitionDelegate
        nav.modalPresentationStyle = .custom
        present(nav, animated: true, completion: nil)
    }

    @IBAction func myAddressTapped(_ sender: Any) {
        //Couldn't get storyboard to work with this DeckTransition
        //self.performSegue(withIdentifier: "myAddress", sender: nil)
        let modal = UIStoryboard(name: "Account", bundle: nil).instantiateViewController(withIdentifier: "MyAddressNavigationController")

        let transitionDelegate = DeckTransitioningDelegate()
        modal.transitioningDelegate = transitionDelegate
        modal.modalPresentationStyle = .custom
        present(modal, animated: true, completion: nil)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "segueToWebview" {
            guard let dest = segue.destination as? TransactionWebViewController else {
                fatalError("Undefined Segue behavior")
            }
            dest.transactionID = selectedTransactionID
        }
    }

    @IBAction func claimTapped(_ sender: Any) {
        Authenticated.account?.claimGas { _, error in
            if error != nil {
                return
            }
            self.loadClaimableGAS()
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch tableView {

        //DEFINITELY NEED A BETTER STRUCT TO MANaGE TRANSACTION HISTORIES
        case historyTableView:
            let transactionEntry = transactionHistory[indexPath.row]
            let isNeoTransaction = transactionEntry.gas == 0 ? true : false
            var transactionData: TransactionCell.TransactionData?
            if isNeoTransaction {
                transactionData = TransactionCell.TransactionData(type: TransactionCell.TransactionType.send, date: transactionEntry.blockIndex,
                                                                  asset: "Neo", address: transactionEntry.transactionID, amount: Double(transactionEntry.neo), precision: 0)
            } else {
                transactionData = TransactionCell.TransactionData(type: TransactionCell.TransactionType.send, date: transactionEntry.blockIndex,
                                                                  asset: "Gas", address: transactionEntry.transactionID, amount: transactionEntry.gas, precision: 8)
            }
            let transactionCellData = transactionData!
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "transactionCell") as? TransactionCell else {
                fatalError("Undefined table view behavior")
            }
            cell.data = transactionCellData
            return cell
        default: fatalError("Undefined table view behavior")
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch tableView {
        case historyTableView:

            selectedTransactionID  = transactionHistory[indexPath.row].transactionID
            self.performSegue(withIdentifier: "segueToWebview", sender: nil)

        default: fatalError("undefined table view behavior")

        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch tableView {

        case historyTableView:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "transactionsHeaderCell") as? TransactionsHeaderCell else {
                fatalError("undefined table view behavior")
            }
            return cell
        default: fatalError("undefined table view behavior")
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch tableView {
        case historyTableView:
            return 44
        default: return 0
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch tableView {

        case historyTableView:
            return transactionHistory.count
        default: return 0
        }
    }

    @IBAction func unwindToAccount(segue: UIStoryboardSegue) {
    }

}

extension AccountViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        return CGSize(width: UIScreen.main.bounds.size.width * 0.6, height: 120)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 2
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch indexPath.row {
        case 0:
            let assetData = AssetCollectionViewCell.AssetData(assetName: "NEO", assetAmount: Double(neoBalance ?? 0), precision: 0)

            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "accountAssetCell", for: indexPath) as? AssetCollectionViewCell else {
                fatalError("undefined table view behavior")
            }
            cell.data = assetData
            return cell
        case 1:
            let assetData = AssetCollectionViewCell.AssetData(assetName: "GAS", assetAmount: Double(gasBalance ?? 0), precision: 8)
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "accountAssetCell", for: indexPath) as? AssetCollectionViewCell else {
                fatalError("undefined table view behavior")
            }
            cell.data = assetData
            return cell
        default: fatalError("undefined table view behavior")
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let assetDetailViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "AssetDetailViewController") as? AssetDetailViewController {
            switch indexPath.row {
            case 0:
                assetDetailViewController.selectedAsset = "neo"
            case 1:
                assetDetailViewController.selectedAsset = "gas"

            default: fatalError("undefined collectionView behavior")
            }
            let nav = WalletHomeNavigationController(rootViewController: assetDetailViewController)
            nav.navigationBar.prefersLargeTitles = true
            nav.navigationItem.largeTitleDisplayMode = .automatic
            assetDetailViewController.navigationItem.leftBarButtonItem = UIBarButtonItem(image: #imageLiteral(resourceName: "times"), style: .plain, target: self, action: #selector(tappedLeftBarButtonItem(_:)))

            let transitionDelegate = DeckTransitioningDelegate()
            nav.transitioningDelegate = transitionDelegate
            nav.modalPresentationStyle = .custom
            present(nav, animated: true, completion: nil)
        }

    }

    @IBAction func tappedLeftBarButtonItem(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }

}
