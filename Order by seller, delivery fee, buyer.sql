SELECT      date_trunc('month', timezone('Asia/Jakarta',"order".created_at)) order_date
            , ou.order_id
            , s.unique_id
            , city.name city
            , province.name province
            , s.address_latitude
            , s.address_longitude
            , "order".id
            , CASE WHEN fee_group.name = 'ONLINE' THEN fee_group.name ELSE 'OFFLINE' END acquisition_channel
            , CASE
                WHEN payment.payment_method_detail_type LIKE 'BANK_TRANSFER%' THEN 'BANK_TRANSFER'
                WHEN payment.payment_method_detail_type LIKE 'VIRTUAL_ACCOUNT%' THEN 'VIRTUAL_ACCOUNT'
                ELSE payment.payment_method_detail_type
              END payment_method
            , ou.GMV_order
            , ou.GMV_final
            , order_fulfilment.status fulfilment_status
            , order_fulfilment.delivery_method
FROM        "gada-marketplace".transaction t
LEFT JOIN   "gada-marketplace"."order" ON t.id = "order".transaction_id
LEFT JOIN   "gada-marketplace".order_fulfilment ON "order".id = order_fulfilment.order_id
LEFT JOIN   "gada-marketplace".payment ON t.id = payment.transaction_id
LEFT JOIN   "gada-marketplace".store s ON t.buyer_store_id = s.id
LEFT JOIN   "gada-marketplace".store seller ON "order".seller_store_id = seller.id
LEFT JOIN   "gada-marketplace".fee_group ON s.fee_group_id = fee_group.id
LEFT JOIN   "gada-marketplace".address_area city on city.id = s.address_city_id
LEFT JOIN   "gada-marketplace".address_area province on province.id = city.parent_area_id
LEFT JOIN   (
            SELECT      ou.order_id
                        --, sum(seller_fee_amount) seller_fee_amount
                        --, sum(seller_fee_discount) seller_fee_discount
                        --, sum(seller_fee_amount - seller_fee_discount) total_nett_fee
                        , sum(unit_price* ordered_quantity) GMV_order
                        --, sum(unit_price* CASE WHEN of.delivery_method = 'GADA_LOGISTIC' THEN (final_picked_quantity - final_returned_quantity) ELSE final_delivered_quantity END) GMV_final_seller
                        , sum(unit_price* final_delivered_quantity) GMV_final
            FROM        "gada-marketplace".order_unit ou
            LEFT JOIN   "gada-marketplace".order_fulfilment of ON ou.order_id = of.order_id
            GROUP BY    ou.order_id
            ) ou ON "order".id = ou.order_id
WHERE       1=1 AND "order".created_at > '20210201'  AND "order".created_at < '20210225' AND order_fulfilment.status = 'COMPLETED'  AND GMV_order <= 15000000
            AND  s.unique_id in
        (
            'GADA-gRwb'
            )

