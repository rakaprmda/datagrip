with raw as (
SELECT      date_trunc('month', timezone('Asia/Jakarta',"order".created_at)) order_date
            , ou.order_id
            , s.unique_id buyer_unique_id
            , ou.product_unit_id
            , ou.product
            , ou.long_name
            , ou.unit_price
            , seller.unique_id seller_unique_id
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
FROM        transaction t
LEFT JOIN   "order" ON t.id = "order".transaction_id
LEFT JOIN   order_fulfilment ON "order".id = order_fulfilment.order_id
LEFT JOIN   payment ON t.id = payment.transaction_id
LEFT JOIN   store s ON t.buyer_store_id = s.id
LEFT JOIN   fee_group ON s.fee_group_id = fee_group.id
LEFT JOIN   address_area city on city.id = s.address_city_id
LEFT JOIN   address_area province on province.id = city.parent_area_id
LEFT JOIN   store seller ON "order".seller_store_id = seller.id
LEFT JOIN   (
            SELECT      ou.order_id
                        ,pu.id product_unit_id
                        ,pv.name as product
                        ,uom.long_name
                        ,unit_price
                        --, sum(seller_fee_amount) seller_fee_amount
                        --, sum(seller_fee_discount) seller_fee_discount
                        --, sum(seller_fee_amount - seller_fee_discount) total_nett_fee
                        , sum(unit_price* ordered_quantity) GMV_order
                        --, sum(unit_price* CASE WHEN of.delivery_method = 'GADA_LOGISTIC' THEN (final_picked_quantity - final_returned_quantity) ELSE final_delivered_quantity END) GMV_final_seller
                        , sum(unit_price* final_delivered_quantity) GMV_final
            FROM        order_unit ou
            LEFT JOIN   order_fulfilment of ON ou.order_id = of.order_id
            LEFT JOIN   product_unit pu on ou.product_unit_id = pu.id
            LEFT JOIN   product_variant pv ON pu.product_variant_id = pv.id
            LEFT JOIN   unit_of_measurement uom  ON pu.unit_of_measurement_id = uom.id
            GROUP BY    1,2,3,4,5
            ) ou ON "order".id = ou.order_id
WHERE       1=1 AND "order".created_at > '20210201'  AND "order".created_at < '20210225' AND order_fulfilment.status = 'COMPLETED'  AND GMV_order <= 15000000
AND s.unique_id = 'GADA-x3yuqx') ------------------------- HERE

, buyer as (
select buyer_unique_id,product_unit_id, product,long_name as uom, min(unit_price) unit_price, sum(GMV_order) total_gmv, count(distinct seller_unique_id) count_seller
from raw
group by 1,2,3,4
order by 4 desc)

,raw_product as (
select
s.unique_id store_code,
pu.id as product_unit_id,
pv.name as product,
uom.long_name uom,
pt.unit_price

from
product_unit pu  LEFT JOIN   product_variant pv ON pu.product_variant_id = pv.id
left join inventory inv on inv.product_unit_id = pu.id
left join store s on s.id = inv.store_id
LEFT JOIN   unit_of_measurement uom  ON pu.unit_of_measurement_id = uom.id
left join price_tier pt on pt.inventory_id = inv.id

where
inv.is_active = true
and s.is_active = true
and pt.is_active = true
and inv.deleted is null
and pt.deleted is null
and unique_id in
(
 'GADA-xClg',
 'GADA-y5Jd',
 'ELADA',
 'GADA-TGS2',
 'BantanJakarta',
 'GADA-hyaP',
 'WeeJayaKusuma',
 'GADA-JKB1',
 'Oriana',
 'GADA-lnxc20',
 'GADA-xxemmm',
 'GADA-TGK2',
 'IndokopiMakmur',
 'GADA-vivf',
 'GADA-TGS1',
 'Sosro'




)
),

product as (
select
product_unit_id,
product,
uom,
count( distinct store_code) available_store,
min(unit_price) min_unit_price

from raw_product

group by 1,2,3
order by 4 desc)




select
buyer.buyer_unique_id,
buyer.product_unit_id,
buyer.product,
buyer.uom,
count_seller,
total_gmv,
buyer.unit_price buyer_unit_price,
min_unit_price as gada_logistic_min_price,
(buyer.unit_price - min_unit_price) / buyer.unit_price ::float as margin_pecentages,
available_store gada_logistic_available_store

from buyer left join product using(product_unit_id)
