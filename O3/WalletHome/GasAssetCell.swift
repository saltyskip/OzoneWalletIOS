//
//  GasAssetCell.swift
//  O3
//
//  Created by Andrei Terentiev on 9/11/17.
//  Copyright © 2017 drei. All rights reserved.
//

import Foundation
import UIKit

class GasAssetCell: UITableViewCell {
    @IBOutlet weak var assetTitleLabel: UILabel!
    @IBOutlet weak var assetAmountLabel: UILabel!
    @IBOutlet weak var assetFiatPriceLabel: UILabel!
    @IBOutlet weak var assetFiatAmountLabel: UILabel!
    @IBOutlet weak var assetPercentChangeLabel: UILabel!

    struct Data {
        var amount: Double
        var referenceCurrency: Currency
        var latestPrice: PriceData
        var firstPrice: PriceData
    }

    var data: GasAssetCell.Data? {
        didSet {
            guard let amount = data?.amount,
                let referenceCurrency = data?.referenceCurrency,
                let latestPrice = data?.latestPrice,
                let firstPrice = data?.firstPrice else {
                    fatalError("undefined data set")
            }
            assetTitleLabel.text = "GAS"
            assetAmountLabel.text = amount.description

            let precision = referenceCurrency == .btc ? Precision.btc : Precision.usd
            let referencePrice = referenceCurrency == .btc ? latestPrice.averageBTC : latestPrice.averageUSD
            let referenceFirstPrice = referenceCurrency == .btc ? firstPrice.averageBTC : firstPrice.averageUSD
            assetFiatPriceLabel.text = referencePrice.string(precision)
            assetFiatAmountLabel.text = (referencePrice * Double(amount)).string(precision)

            assetPercentChangeLabel.text = String.percentChangeStringShort(latestPrice: latestPrice, previousPrice: firstPrice,
                                                                           referenceCurrency: referenceCurrency)
            assetPercentChangeLabel.textColor = referencePrice >= referenceFirstPrice ? Theme.Light.green : Theme.Light.red
        }
    }
}