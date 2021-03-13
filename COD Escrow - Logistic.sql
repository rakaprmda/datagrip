--Delivery Fee Report - Buyer

SELECT DISTINCT
       DATE("order".delivery_date) delivery_date,
       tp.rpb_number rpb_no,
        pom.entity_id order_id,
       delivery.status delivery_status,
       delivery_tag.status delivery_tag_status,
--        CAST("order".delivery_date AS char(10)) rpb_date,
--        "order".store_name buyer_name,
        "order".payment_type metode_pembayaran,
       da.buyer_code,
--        da.line1 alamat_buyer,
--        da.city kota_buyer,
--        da.district kecamatan_buyer,
--        da.village kelurahan_buyer,
--        reg.name area_buyer,
--        CASE
--        WHEN LOWER(reg.name) = 'bali nusra' THEN 'East'
--        WHEN LOWER(reg.name) = 'jabodetabek 1' THEN 'West'
--        WHEN LOWER(reg.name) = 'jabodetabek 2' THEN 'West'
--        WHEN LOWER(reg.name) = 'jawa barat' THEN 'West'
--        WHEN LOWER(reg.name) = 'jawa tengah' THEN 'East'
--        WHEN LOWER(reg.name) = 'jawa timur' THEN 'East'
--        WHEN LOWER(reg.name) = 'kalimantan' THEN 'East'
--        WHEN LOWER(reg.name) = 'sulawesi papua' THEN 'East'
--        WHEN LOWER(reg.name) = 'sumatera' THEN 'West'
--        END regional_buyer,
--        pa.name as seller_name,
       pa.seller_code,
       dr.vendor_name vendor,
       f.license_plate nopol,
       u.name nama_supir,
       ol.orderGMV,
       ol.totGMV,
       CASE
       WHEN LOWER("order".payment_type) = 'cod' THEN "order".delivery_fee_value
       ELSE 0
       END ongkir
--        CASE
--        WHEN LOWER("order".payment_type) = 'cod' THEN "order".delivery_fee_value / 1.1
--        ELSE 0
--        END DPP,
--        CASE
--        WHEN LOWER("order".payment_type) = 'cod' THEN ("order".delivery_fee_value / 1.1) * 0.1
--        ELSE 0
--        END VAT
        ,(ol.totGMV +  CASE WHEN LOWER("order".payment_type) = 'cod' THEN "order".delivery_fee_value ELSE 0 END) as total
        , sum (ol.totGMV +  CASE WHEN LOWER("order".payment_type) = 'cod' THEN "order".delivery_fee_value ELSE 0 END) OVER (
		PARTITION BY tp.rpb_number)

  FROM delivery
       JOIN "order"
       ON "order".id = delivery.order_id
--        AND {{delivery_status}}

       LEFT JOIN (SELECT iol.order_id,
                         SUM(idl.quantity) order_qty,
                         SUM(idl.allocated_quantity) alocated_qty,
                         SUM(idl.checked_quantity) qty,
                         SUM(iol.price_unit * idl.quantity) orderGMV,
                         SUM(iol.price_unit * idl.allocated_quantity) alocated_qty,
                         SUM(iol.price_unit * idl.checked_quantity) totGMV
                    FROM "order_line" iol
                         JOIN "delivery_line" idl
                         ON iol.id = idl.order_line_id
                   GROUP BY iol.order_id) ol
       ON ol.order_id = delivery.order_id
          AND ol.qty > 0


       LEFT JOIN pickup_address pa
       ON delivery.pickup_address_id = pa.id

       LEFT JOIN delivery_address da
       ON delivery.delivery_address_id = da.id

       LEFT JOIN task t
       ON delivery.id = t.delivery_id

       LEFT JOIN (SELECT ride_id,
                         pickup_id,
                         pickup_address_id,
                         rpb_number
                    FROM task t
                         LEFT JOIN pickup p ON t.pickup_id = p.id
                   WHERE pickup_id IS NOT NULL) tp
       ON t.ride_id = tp.ride_id
       AND delivery.pickup_address_id = tp.pickup_address_id

       LEFT JOIN ride r
       ON r.id = t.ride_id

       LEFT JOIN driver dr
       ON dr.id = t.driver_id

       LEFT JOIN "user" u
       ON u.id = dr.user_id

       LEFT JOIN fleet f
       ON dr.fleet_id = f.id

       LEFT JOIN batch b
       ON b.id = delivery.batch_id

       LEFT JOIN region reg
       ON reg.id = b.region_id

       LEFT JOIN provider_order_mappings pom
       ON pom.order_id = delivery.order_id

       LEFT JOIN delivery_tag
       ON delivery_tag.id = delivery.delivery_tag_id
 WHERE
--    {{delivery_date}}
--    AND {{delivery_tag_status}}
    delivery.deleted IS NULL
    AND delivery.status = 'done'
   AND "delivery".status = 'done'
    AND lower("order".payment_type) = 'cod'
--    [[AND CAST(tp.rpb_number AS VARCHAR) ILIKE '%'||{{rpb_number}}||'%']]
 ORDER BY DATE("order".delivery_date) desc