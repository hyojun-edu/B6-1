-- Cafe Order DB: 핵심 쿼리 18개
PRAGMA foreign_keys = ON;

-- Q01 기본 조회: 판매 중인 메뉴만 가격 오름차순으로 확인
SELECT item_id, item_name, price FROM menu_items
WHERE is_available = 1 ORDER BY price ASC, item_name LIMIT 5;

-- Q02 기본 조회: 이름에 '라떼'가 포함된 메뉴 검색
SELECT item_name, price FROM menu_items
WHERE item_name LIKE '%라떼%' ORDER BY price DESC;

-- Q03 기본 조회: 최신 주문 5건 확인
SELECT order_id, customer_id, ordered_at, order_status FROM orders
ORDER BY ordered_at DESC LIMIT 5;

-- Q04 기본 조회: 6월 5일 이후 완료 주문 검색
SELECT order_id, customer_id, ordered_at FROM orders
WHERE ordered_at >= '2025-06-05' AND order_status = 'COMPLETED'
ORDER BY ordered_at;

-- Q05 INNER JOIN: 주문과 고객 이름 연결
SELECT o.order_id, c.name, o.ordered_at, o.order_status
FROM orders o INNER JOIN customers c ON c.customer_id = o.customer_id
ORDER BY o.order_id LIMIT 8;

-- Q06 INNER JOIN: 주문 상세와 메뉴명 연결
SELECT oi.order_id, m.item_name, oi.quantity, oi.unit_price
FROM order_items oi INNER JOIN menu_items m ON m.item_id = oi.item_id
ORDER BY oi.order_id, oi.order_item_id LIMIT 10;

-- Q07 INNER JOIN: 주문/고객/메뉴를 한 번에 확인
SELECT o.order_id, c.name AS customer_name, m.item_name, oi.quantity
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
JOIN menu_items m ON m.item_id = oi.item_id
WHERE o.order_status <> 'CANCELLED'
ORDER BY o.order_id LIMIT 10;

-- Q08 LEFT JOIN: 주문이 한 번도 없는 고객도 포함
SELECT c.customer_id, c.name, COUNT(o.order_id) AS order_count
FROM customers c LEFT JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.name ORDER BY order_count DESC, c.customer_id;

-- Q09 GROUP BY/COUNT: 카테고리별 메뉴 수
SELECT mc.category_name, COUNT(mi.item_id) AS menu_count
FROM menu_categories mc LEFT JOIN menu_items mi ON mi.category_id = mc.category_id
GROUP BY mc.category_id, mc.category_name ORDER BY menu_count DESC, mc.category_id;

-- Q10 GROUP BY/SUM: 메뉴별 판매 수량
SELECT m.item_name, SUM(oi.quantity) AS sold_quantity
FROM menu_items m JOIN order_items oi ON oi.item_id = m.item_id
GROUP BY m.item_id, m.item_name ORDER BY sold_quantity DESC, m.item_id;

-- Q11 GROUP BY/AVG: 카테고리별 평균 메뉴 가격
SELECT mc.category_name, ROUND(AVG(mi.price), 0) AS average_price
FROM menu_categories mc JOIN menu_items mi ON mi.category_id = mc.category_id
GROUP BY mc.category_id, mc.category_name ORDER BY average_price DESC;

-- Q12 GROUP BY/SUM: 고객별 누적 주문 금액(취소 주문 제외)
SELECT c.name, SUM(oi.quantity * oi.unit_price) AS total_spent
FROM customers c JOIN orders o ON o.customer_id = c.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status <> 'CANCELLED'
GROUP BY c.customer_id, c.name ORDER BY total_spent DESC;

-- Q13 서브쿼리: 평균 메뉴 가격보다 비싼 메뉴
SELECT item_name, price FROM menu_items
WHERE price > (SELECT AVG(price) FROM menu_items)
ORDER BY price DESC;

-- Q14 서브쿼리: 주문을 한 번도 하지 않은 고객
SELECT customer_id, name FROM customers
WHERE customer_id NOT IN (SELECT customer_id FROM orders)
ORDER BY customer_id;

-- Q15 UPDATE: 품절 메뉴의 판매 상태 변경
UPDATE menu_items SET is_available = 1 WHERE item_name = '말차크림라떼';
SELECT item_id, item_name, is_available FROM menu_items WHERE item_name = '말차크림라떼';

-- Q16 DELETE: 취소 주문의 상세 데이터 삭제(ON DELETE CASCADE 확인)
DELETE FROM orders WHERE order_status = 'CANCELLED';
SELECT COUNT(*) AS remaining_cancelled_orders FROM orders WHERE order_status = 'CANCELLED';

-- Q17 인덱스 확인: 주문일시 인덱스를 사용하는 최근 주문 조회
EXPLAIN QUERY PLAN
SELECT order_id, ordered_at FROM orders
WHERE ordered_at >= '2025-06-08' ORDER BY ordered_at;

-- Q18 미니 리포트: 주문 상태별 건수와 금액
SELECT o.order_status, COUNT(DISTINCT o.order_id) AS order_count,
       COALESCE(SUM(oi.quantity * oi.unit_price), 0) AS order_amount
FROM orders o LEFT JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY o.order_status ORDER BY order_amount DESC;

-- BONUS Q19 같은 요구를 JOIN으로 해결: 주문 이력이 있는 고객 목록
SELECT DISTINCT c.customer_id, c.name
FROM customers c JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_status <> 'CANCELLED'
ORDER BY c.customer_id;

-- BONUS Q20 같은 요구를 EXISTS 서브쿼리로 해결: 주문 이력이 있는 고객 목록
SELECT c.customer_id, c.name
FROM customers c
WHERE EXISTS (
    SELECT 1 FROM orders o
    WHERE o.customer_id = c.customer_id AND o.order_status <> 'CANCELLED'
)
ORDER BY c.customer_id;

-- BONUS Q21 미니 리포트 지표 1: 월별 완료 주문 건수와 매출
SELECT substr(o.ordered_at, 1, 7) AS order_month,
       COUNT(DISTINCT o.order_id) AS completed_order_count,
       SUM(oi.quantity * oi.unit_price) AS completed_sales
FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status = 'COMPLETED'
GROUP BY substr(o.ordered_at, 1, 7)
ORDER BY order_month;

-- BONUS Q22 미니 리포트 지표 2: 인기 메뉴 TOP 10
SELECT m.item_name, SUM(oi.quantity) AS sold_quantity,
       SUM(oi.quantity * oi.unit_price) AS sales_amount
FROM menu_items m JOIN order_items oi ON oi.item_id = m.item_id
JOIN orders o ON o.order_id = oi.order_id
WHERE o.order_status <> 'CANCELLED'
GROUP BY m.item_id, m.item_name
ORDER BY sold_quantity DESC, sales_amount DESC, m.item_id
LIMIT 10;

-- BONUS Q23 미니 리포트 지표 3: 고객별 누적 매출 랭킹
SELECT c.name, SUM(oi.quantity * oi.unit_price) AS total_spent,
       RANK() OVER (ORDER BY SUM(oi.quantity * oi.unit_price) DESC) AS spending_rank
FROM customers c JOIN orders o ON o.customer_id = c.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status <> 'CANCELLED'
GROUP BY c.customer_id, c.name
ORDER BY spending_rank, c.name;
