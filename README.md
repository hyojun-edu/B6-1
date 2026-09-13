# 카페 주문 데이터베이스 SQL 실습

카페 주문을 주제로 데이터 모델링부터 샘플 입력, 조회·조인·집계·수정·삭제까지 SQLite로 구현한 제출물이다. 백엔드 프레임워크나 애플리케이션 코드는 사용하지 않았다.

## 실행 환경

- DB: SQLite 3.51.0 이상 권장
- 실행 도구: `sqlite3` CLI, DBeaver 등 SQLite를 지원하는 도구
- 날짜와 금액은 재현성을 위해 고정된 샘플 값으로 작성했다.

## 제출물

| 파일 | 설명 |
| --- | --- |
| [`schema.sql`](schema.sql) | 5개 테이블, PK/FK, NOT NULL, UNIQUE, CHECK, 인덱스 생성 |
| [`seed.sql`](seed.sql) | 부모 테이블부터 입력하는 샘플 데이터 INSERT |
| [`queries.sql`](queries.sql) | 설명이 붙은 핵심 SQL 18개 |
| [`results/query_results.txt`](results/query_results.txt) | 위 쿼리를 실제 SQLite에서 실행한 결과 텍스트 |

## 실행 방법

저장소 루트에서 다음 명령을 실행하면 스키마 생성, 데이터 입력, 쿼리 실행을 한 번에 재현할 수 있다.

```bash
sqlite3 cafe.db < schema.sql
sqlite3 cafe.db < seed.sql
sqlite3 -header -column cafe.db < queries.sql
```

처음부터 다시 실행하려면 `schema.sql`이 기존 테이블을 삭제하고 재생성하므로 다음처럼 실행한다.

```bash
rm -f cafe.db
sqlite3 cafe.db < schema.sql
sqlite3 cafe.db < seed.sql
sqlite3 -header -column cafe.db < queries.sql
```

메모리 DB에서 파일을 만들지 않고 재현하는 방법은 다음과 같다.

```bash
sqlite3 -header -column :memory: < <(cat schema.sql seed.sql queries.sql)
```

## 데이터 모델

```text
customers (1) ───< orders (1) ───< order_items >─── (1) menu_items >─── (1) menu_categories
```

- `customers.customer_id` → `orders.customer_id`: 고객 1명은 여러 주문을 할 수 있다.
- `orders.order_id` → `order_items.order_id`: 주문 1건은 여러 주문 상세를 가진다.
- `menu_categories.category_id` → `menu_items.category_id`: 카테고리 1개는 여러 메뉴를 가진다.
- `menu_items.item_id` → `order_items.item_id`: 메뉴 1개가 여러 주문 상세에 담길 수 있다.

각 테이블의 PK는 행을 식별하고, FK는 존재하는 부모 데이터만 참조하도록 관계와 무결성을 보장한다. `customers.email`, `menu_categories.category_name`, `menu_items.item_name`에는 UNIQUE를 적용했으며, 주요 컬럼에는 NOT NULL과 CHECK 제약조건을 적용했다. 주문 삭제 시 상세도 함께 삭제되도록 `ON DELETE CASCADE`를 사용했다.

초기 데이터 행 수는 `customers` 10, `menu_categories` 10, `menu_items` 15, `orders` 12, `order_items` 23개다.

## 쿼리 구성

`queries.sql`의 18개 쿼리는 요구 범주를 모두 포함한다.

- Q01~Q04: `WHERE`, `ORDER BY`, `LIMIT`을 사용한 기본 조회 4개
- Q05~Q08: INNER JOIN 3개와 LEFT JOIN 1개
- Q09~Q12: `COUNT`, `SUM`, `AVG`와 `GROUP BY`를 사용한 집계 4개
- Q13~Q14: 평균 비교·미주문 고객을 찾는 서브쿼리 2개
- Q15: 품절 메뉴를 판매 가능으로 바꾸는 `UPDATE`
- Q16: 취소 주문을 삭제하고 FK의 `ON DELETE CASCADE`를 확인하는 `DELETE`
- Q17: `CREATE INDEX`로 만든 인덱스의 사용 여부를 `EXPLAIN QUERY PLAN`으로 확인
- Q18: 주문 상태별 주문 건수와 금액을 제공하는 미니 리포트

각 쿼리의 의도는 SQL 파일의 바로 위 주석에 한 줄로 적었고, 실행 결과는 [`results/query_results.txt`](results/query_results.txt)에 남겼다. Q15와 Q16은 데이터 상태를 변경하므로 같은 DB에서 반복 실행할 때 결과가 달라질 수 있다. 결과 파일은 초기화 후 전체 스크립트를 한 번 실행한 결과다.

## 과제 목표 정리

### 데이터베이스와 엑셀의 차이, 테이블을 나누는 이유

엑셀은 한 시트에 데이터를 자유롭게 입력하고 사람이 직접 중복과 규칙을 관리하는 데 강하다. 반면 데이터베이스는 여러 사용자가 동시에 데이터를 다뤄도 정해진 규칙과 관계를 지키도록 저장하고, 조건에 맞는 데이터를 SQL로 반복해서 정확하게 조회하는 데 적합하다. 즉, 차이는 단순히 데이터의 양이 아니라 데이터 간 관계와 무결성을 시스템이 관리할 수 있는지에 있다.

이 프로젝트에서 고객·주문·메뉴를 한 테이블에 모두 저장하면 한 고객의 이름이나 메뉴 가격이 주문마다 반복된다. 고객명이나 가격을 수정할 때 여러 행을 함께 수정해야 하고, 일부만 수정하면 서로 다른 값이 남는 문제가 생긴다. 그래서 `customers`, `orders`, `order_items`, `menu_items`, `menu_categories`처럼 역할별로 테이블을 나누고 ID로 연결했다. 이렇게 하면 고객 정보와 메뉴 정보는 한 곳에서만 관리하면서도 주문 조회 때 필요한 데이터는 JOIN으로 다시 조합할 수 있다.

### PK, FK, 그리고 1:N 관계

PK(Primary Key, 기본키)는 테이블 안에서 각 행을 유일하게 식별하는 값이다. 예를 들어 `customers.customer_id`가 1이면 그 값은 한 명의 고객만 가리킨다. PK는 중복될 수 없고 NULL이 될 수 없으므로 다른 데이터가 특정 행을 안전하게 가리킬 수 있다.

FK(Foreign Key, 외래키)는 다른 테이블의 PK를 참조하는 컬럼이다. `orders.customer_id`는 `customers.customer_id`를 참조하므로 존재하지 않는 고객의 주문을 입력할 수 없다. 이 규칙이 데이터 무결성을 보장한다.

1:N 관계는 부모 한 행에 자식 여러 행이 연결되는 관계다. 고객 1명은 여러 주문을 만들 수 있으므로 `customers (1) : orders (N)`이고, 주문 1건은 여러 상품을 포함할 수 있으므로 `orders (1) : order_items (N)`이다. 자식 테이블에 부모의 PK를 저장하는 FK를 두면 이 관계를 표현할 수 있다. 따라서 고객 ID 하나로 그 고객의 모든 주문을 찾고, 주문 ID 하나로 주문 상세 여러 건을 찾을 수 있다.

### SELECT / INSERT / UPDATE / DELETE의 용도

- `SELECT`: 기존 데이터를 읽을 때 사용한다. Q01의 판매 중 메뉴 검색, Q03의 최신 주문 조회처럼 원본 데이터를 바꾸지 않는다.
- `INSERT`: 새로운 행을 추가할 때 사용한다. `seed.sql`에서는 고객을 먼저 입력한 뒤 그 고객을 참조하는 주문을 추가한다.
- `UPDATE`: 이미 존재하는 행의 값을 바꿀 때 사용한다. Q15는 `말차크림라떼`의 판매 가능 상태를 0에서 1로 변경한다. 조건 없이 실행하면 여러 행을 바꿀 수 있으므로 `WHERE`가 중요하다.
- `DELETE`: 더 이상 필요하지 않은 행을 삭제할 때 사용한다. Q16은 취소 주문을 삭제하며, `ON DELETE CASCADE`에 의해 해당 주문의 상세도 함께 삭제된다. 삭제는 복구가 어려울 수 있어 조건과 대상 행을 먼저 확인해야 한다.

### JOIN과 GROUP BY로 연결된 데이터 조회하기

`JOIN`은 공통 키를 기준으로 여러 테이블의 행을 연결한다. 예를 들어 `orders.customer_id = customers.customer_id`로 JOIN하면 주문 ID만 있던 결과에 고객 이름을 함께 표시할 수 있다. Q07은 주문, 고객, 주문 상세, 메뉴를 연속해서 JOIN하여 “누가 어떤 메뉴를 몇 개 주문했는가”를 한 결과에서 보여준다. `LEFT JOIN`은 연결되는 자식 행이 없어도 왼쪽 테이블의 행을 유지하므로 Q08처럼 주문이 없는 고객까지 포함할 때 사용한다.

`GROUP BY`는 같은 기준의 행을 그룹으로 묶고 `COUNT`, `SUM`, `AVG` 같은 집계 함수를 적용한다. Q09는 카테고리별 메뉴 수를 세고, Q10은 메뉴별 판매 수량을 합산하며, Q12는 고객별 누적 주문 금액을 계산한다. 즉, JOIN이 여러 테이블의 상세 정보를 연결하는 도구라면 GROUP BY는 연결된 데이터를 기준별 요약값으로 바꾸는 도구다.

### 검색·정렬·집계·랭킹 요구를 SQL로 해결하는 방법

실무 요구는 조건, 정렬, 집계 함수를 조합해 해결한다.

- 검색: `WHERE item_name LIKE '%라떼%'`처럼 조건을 지정한다. Q02는 메뉴명에 특정 단어가 포함된 메뉴를 찾는다.
- 정렬: `ORDER BY ordered_at DESC`처럼 최신순·가격순을 지정한다. Q03은 최근 주문을 먼저 보여준다.
- 결과 수 제한: `LIMIT 5`를 사용해 화면에 보여줄 상위 결과만 가져온다.
- 집계: `COUNT`는 건수, `SUM`은 합계, `AVG`는 평균을 구하며 `GROUP BY`와 함께 카테고리별·고객별 지표를 만든다.
- 랭킹: 집계 결과에 `ORDER BY sold_quantity DESC`를 적용하면 판매량 TOP 목록이 된다. Q10은 메뉴별 판매 수량을 계산해 많이 팔린 메뉴부터 정렬한다.

이처럼 “무엇을 찾는가”는 `WHERE`, “어떤 순서인가”는 `ORDER BY`, “얼마나 요약할 것인가”는 집계 함수와 `GROUP BY`로 나누어 생각하면 복잡한 요구도 SQL로 단계적으로 표현할 수 있다.

### 인덱스가 필요한 이유와 적용 대상

인덱스는 책의 색인처럼 특정 컬럼의 값을 빠르게 찾도록 별도 자료구조를 만드는 기능이다. 인덱스가 없으면 조건에 맞는 행을 찾기 위해 테이블 전체를 순서대로 확인할 수 있지만, 인덱스가 있으면 필요한 범위를 빠르게 찾아 조회 시간을 줄일 수 있다. Q17의 `EXPLAIN QUERY PLAN` 결과에서 `idx_orders_ordered_at`이 사용되는 것을 확인할 수 있다.

인덱스는 모든 컬럼에 만들기보다 `WHERE`, `JOIN`, `ORDER BY`에 자주 사용되고 값의 구분도 충분한 컬럼에 적용하는 것이 좋다. 이 프로젝트에서는 카테고리 JOIN에 사용하는 `menu_items.category_id`와 기간·최신순 조회가 잦은 `orders.ordered_at`에 인덱스를 만들었다. 대신 인덱스는 저장 공간을 추가로 사용하고 `INSERT`·`UPDATE`·`DELETE` 때도 갱신 비용이 발생하므로, 거의 검색하지 않는 컬럼이나 값의 종류가 지나치게 적은 컬럼에는 신중하게 적용해야 한다.

## 보너스 확인

- 같은 요구를 JOIN으로 풀기: Q08은 `LEFT JOIN`으로 고객별 주문 수를 구하고, Q14는 서브쿼리로 주문이 없는 고객을 구한다. JOIN은 관련 집계까지 확장하기 좋고, `NOT IN` 서브쿼리는 존재 여부를 간결하게 표현한다.
- FK 오류 재현 예시:

  ```sql
  PRAGMA foreign_keys = ON;
  INSERT INTO orders (order_id, customer_id, ordered_at, order_status)
  VALUES (99, 999, '2025-06-12 10:00:00', 'PAID');
  ```

  존재하지 않는 `customer_id = 999`를 참조하므로 `FOREIGN KEY constraint failed`가 발생한다. `customers`에 실제 고객을 먼저 입력하거나 올바른 고객 ID를 사용해야 한다.

## 제한 사항 준수

뷰, 프로시저, 트리거 및 백엔드 프레임워크는 사용하지 않았다. 모든 결과물은 로컬 SQLite CLI에서 실행 가능하며, 스키마 생성 순서와 부모-자식 데이터 입력 순서를 지켰다.
