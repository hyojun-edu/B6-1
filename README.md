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

### ACID 트랜잭션 관점에서 데이터베이스를 사용하는 이유

데이터베이스는 단순히 표 형태로 값을 저장하는 도구가 아니라, 여러 데이터 변경을 안전한 하나의 작업 단위로 처리하는 트랜잭션 기능을 제공한다. 트랜잭션의 대표적인 성질은 ACID다.

- **Atomicity(원자성)**: 트랜잭션 안의 작업은 전부 성공하거나 전부 취소되어야 한다. `seed.sql`은 `BEGIN TRANSACTION`으로 고객·메뉴·주문·주문 상세 입력을 시작하고 마지막에 `COMMIT`한다. 중간 INSERT가 실패하면 전체 입력을 롤백할 수 있어 일부 테이블에만 데이터가 들어간 불완전한 상태를 피할 수 있다.
- **Consistency(일관성)**: 작업 전후에 데이터가 정해진 규칙을 만족해야 한다. 이 프로젝트의 PK, FK, `NOT NULL`, `UNIQUE`, `CHECK` 제약조건이 이를 보장한다. 예를 들어 존재하지 않는 고객을 주문의 `customer_id`로 넣을 수 없고, 수량이 0 이하인 주문 상세도 저장할 수 없다.
- **Isolation(격리성)**: 여러 트랜잭션이 동시에 실행되어도 서로의 중간 처리 상태를 함부로 보지 않도록 분리한다. 예를 들어 주문과 주문 상세를 입력하는 중간 단계의 불완전한 데이터를 다른 작업이 정상 주문처럼 읽지 않게 하여 동시 작업에서 발생하는 충돌과 잘못된 조회를 줄인다. SQLite도 트랜잭션 단위로 변경을 처리해 읽기와 쓰기의 일관성을 관리한다.
- **Durability(지속성)**: `COMMIT`이 완료된 데이터는 프로그램이 종료되거나 다시 실행되어도 보존되어야 한다. SQLite는 커밋된 내용을 `cafe.db` 파일에 저장하므로 메모리만 사용하는 방식과 달리 다음 접속에서도 주문과 고객 데이터를 다시 사용할 수 있다.

따라서 엑셀에서 여러 행을 직접 수정하다가 중간에 저장되거나 일부 값만 바뀌는 위험을 데이터베이스에서는 트랜잭션과 제약조건으로 줄일 수 있다. 특히 주문 생성처럼 고객 확인, 주문 생성, 주문 상세 입력이 함께 성공해야 하는 작업은 ACID가 보장되어야 업무 데이터가 신뢰성을 갖는다. 다만 ACID는 백업을 대신하지 않으므로 중요한 운영 데이터에는 별도의 백업과 복구 정책도 필요하다.

### 정규화를 통한 데이터 중복과 이상 현상 감소

관계형 데이터베이스를 사용할 때는 정규화 원칙에 따라 하나의 사실을 한 곳에서 관리하도록 테이블을 나눌 수 있다. 정규화는 데이터베이스가 자동으로 수행하는 기능이 아니라, 도메인의 속성과 관계를 분석해 스키마를 설계하는 방법이다. 이 프로젝트에서는 다음처럼 고객, 주문, 메뉴의 정보를 분리했다.

- 고객 정보는 `customers`에 한 번만 저장하고 `orders.customer_id`로 참조한다.
- 메뉴와 가격은 `menu_items`에 저장하고, 주문 당시의 수량과 가격 정보는 `order_items`에서 관리한다.
- 카테고리명은 `menu_categories`에 한 번만 저장하고 `menu_items.category_id`로 연결한다.

이렇게 설계하면 같은 고객명·이메일·카테고리명이 주문 행마다 반복되지 않아 저장 중복이 줄고, 고객이나 메뉴 정보를 수정할 때 한 행만 바꾸면 된다. 그 결과 다음과 같은 이상 현상을 줄일 수 있다.

- **갱신 이상**: 중복된 고객명이나 메뉴 가격 중 일부만 수정되어 서로 다른 값이 남는 문제를 줄인다.
- **삽입 이상**: 아직 주문하지 않은 고객이나 아직 판매되지 않은 메뉴도 각각의 테이블에 독립적으로 등록할 수 있다.
- **삭제 이상**: 한 주문을 삭제해도 고객 정보나 메뉴 정보까지 함께 사라지지 않는다. 주문 상세만 `ON DELETE CASCADE`로 함께 정리된다.

정규화된 구조는 데이터의 일관성과 유지보수성을 높이는 대신 조회할 때 여러 테이블을 JOIN해야 할 수 있다. 이 프로젝트는 저장 시에는 정보를 분리해 무결성과 중복 방지를 얻고, 조회 시에는 JOIN과 집계로 필요한 화면용 결과를 다시 만드는 방식이다. 즉, 데이터베이스의 장점은 단순히 파일을 대체하는 데 있지 않고, 정규화된 구조·키·제약조건·트랜잭션을 함께 사용해 신뢰할 수 있는 데이터를 관리하는 데 있다.

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

### `queries.sql`에 사용한 SQL 문법 해설

#### JOIN 관련 구문

```sql
FROM orders o
INNER JOIN customers c ON c.customer_id = o.customer_id
```

- `JOIN`은 두 테이블의 관련 행을 연결한다. `o`, `c`는 테이블 별칭(alias)으로 긴 테이블명을 짧게 표현한다.
- `ON` 뒤에는 어떤 컬럼을 기준으로 연결할지 적는다. 여기서는 주문의 고객 FK와 고객의 PK를 연결한다.
- `INNER JOIN`은 양쪽 테이블에 모두 일치하는 행만 반환한다. Q05~Q07처럼 유효한 고객과 주문 상세가 연결된 결과를 얻을 때 사용한다. 일치하는 부모가 없는 자식 행은 결과에서 제외된다.
- 여러 JOIN을 이어 쓰면 Q07처럼 주문 → 고객 → 주문 상세 → 메뉴를 한 번에 연결할 수 있다.

```sql
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
```

- `LEFT JOIN`은 왼쪽 테이블의 모든 행을 유지하고, 오른쪽 테이블에 일치하는 행이 없으면 오른쪽 컬럼을 `NULL`로 채운다.
- Q08은 주문이 한 번도 없는 고객도 보여주기 위해 `customers`를 왼쪽에 두었다. `INNER JOIN`이었다면 주문이 없는 고객은 사라진다.
- Q09도 `menu_categories`를 왼쪽에 두어 메뉴가 0개인 `원두` 카테고리까지 결과에 포함한다.
- JOIN 결과에 같은 고객이나 메뉴가 여러 번 나타날 수 있을 때 `DISTINCT`를 사용하면 중복을 제거할 수 있다. BONUS Q19가 이 방식으로 고객 목록을 한 번씩 반환한다.

#### 집계 함수와 GROUP BY

- `COUNT(*)`: 그룹에 속한 전체 행 수를 센다.
- `COUNT(column)`: 해당 컬럼이 `NULL`이 아닌 행만 센다. Q08의 `COUNT(o.order_id)`는 주문이 없는 고객의 NULL을 세지 않아 0이 된다.
- `SUM(expression)`: 수량이나 금액의 합계를 계산한다. Q10은 `quantity`를, Q12는 `quantity * unit_price`를 합산한다.
- `AVG(column)`: 컬럼의 평균을 계산한다. Q11은 카테고리별 메뉴 가격 평균을 구한다.
- `ROUND(value, 0)`: Q11에서 평균 가격을 소수점 0자리로 반올림한다.

집계 함수를 기준별로 적용하려면 `GROUP BY`를 함께 사용한다.

```sql
SELECT m.item_name, SUM(oi.quantity) AS sold_quantity
FROM menu_items m
JOIN order_items oi ON oi.item_id = m.item_id
GROUP BY m.item_id, m.item_name
ORDER BY sold_quantity DESC;
```

이 쿼리는 메뉴별로 행을 묶은 뒤 판매 수량을 합산하고, 별칭 `sold_quantity`를 기준으로 많이 팔린 순서로 정렬한다. SELECT에 집계하지 않은 일반 컬럼을 함께 표시할 때는 보통 그 컬럼을 `GROUP BY`에도 적는다. Q09~Q12는 이 패턴으로 카테고리별 메뉴 수, 메뉴별 판매량, 카테고리별 평균 가격, 고객별 지출액을 계산한다.

#### `substr` 함수

`substr(text, start, length)`는 문자열의 일부를 잘라내는 SQLite 함수다. 시작 위치는 1부터 센다.

```sql
substr(o.ordered_at, 1, 7)
```

`2025-06-10 17:50:00`에서 첫 7글자인 `2025-06`을 추출한다. BONUS Q21은 이 값을 `GROUP BY`에 사용해 주문을 연도-월별로 묶는다. 날짜를 월 단위로 집계하기 위한 SQLite 전용 문자열 처리 방식이며, PostgreSQL이나 MySQL에서는 날짜 함수 문법이 달라질 수 있다.

#### `COALESCE` 함수

`COALESCE(value1, value2, ...)`는 왼쪽부터 확인해 처음으로 `NULL`이 아닌 값을 반환한다.

```sql
COALESCE(SUM(oi.quantity * oi.unit_price), 0) AS order_amount
```

Q18은 `orders`에 `LEFT JOIN`을 사용하므로 주문 상세가 없는 상태가 있으면 `SUM(...)` 결과가 `NULL`이 될 수 있다. 이때 `COALESCE`가 `NULL`을 숫자 0으로 바꾸어 금액이 없는 상태도 `0`으로 표시한다. 데이터가 없다는 의미의 `NULL`과 실제 합계가 0이라는 표시를 결과에서 명확하게 구분하지 않고 숫자로 보여줄 때 유용하다.

#### 서브쿼리와 랭킹

Q13~Q14와 BONUS Q20은 괄호 안에 별도의 SELECT를 넣는 서브쿼리다. Q13은 전체 메뉴 평균 가격을 먼저 구해 그보다 비싼 메뉴를 찾고, BONUS Q20은 `EXISTS`로 고객별 주문 존재 여부를 확인한다. BONUS Q23의 `RANK() OVER (ORDER BY ...)`는 집계된 고객 매출에 순위를 부여하며, 같은 금액이면 같은 순위를 준다.

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

## 보너스 과제

보너스 과제는 기본 쿼리 Q01~Q18과 구분하여 `queries.sql`의 BONUS Q19~Q23으로 작성했다. 실행 결과도 [`results/query_results.txt`](results/query_results.txt)에 별도로 기록했다.

### 1. 같은 요구를 JOIN과 서브쿼리로 풀기

요구사항을 “취소되지 않은 주문 이력이 있는 고객 목록”으로 통일했다.

- BONUS Q19: `customers`와 `orders`를 `JOIN`하고 `DISTINCT`로 고객을 중복 없이 반환한다. 취소 주문은 제외한다.
- BONUS Q20: 각 고객에 대해 취소되지 않은 주문의 존재 여부를 `EXISTS` 서브쿼리로 확인한다.

두 쿼리는 같은 고객 목록을 반환한다. JOIN 방식은 주문 정보나 주문별 집계를 함께 확장하기 쉽고, `EXISTS` 방식은 관련 행의 존재 여부만 확인할 때 의도가 분명하며 불필요한 중복 행을 만들지 않는다.

### 2. 데이터 정합성 깨뜨려 보기

아래처럼 존재하지 않는 고객 ID를 주문의 FK로 입력하면 오류가 발생한다.

  ```sql
  PRAGMA foreign_keys = ON;
  INSERT INTO orders (order_id, customer_id, ordered_at, order_status)
  VALUES (99, 999, '2025-06-12 10:00:00', 'PAID');
  ```

  존재하지 않는 `customer_id = 999`를 참조하므로 `FOREIGN KEY constraint failed`가 발생한다. `customers`에 실제 고객을 먼저 입력하거나 올바른 고객 ID를 사용해야 한다.

### 3. 미니 리포트: 핵심 지표 3개

BONUS Q21~Q23에서 이 데이터베이스로 확인할 핵심 지표를 다음처럼 정의했다.

1. **월별 완료 주문 건수와 매출** — 기간별 주문량과 매출 추이를 확인한다. Q21은 `substr(ordered_at, 1, 7)`로 월을 묶고 완료 주문만 집계한다.
2. **인기 메뉴 TOP 10** — 어떤 메뉴가 많이 팔렸는지 확인해 메뉴 운영과 재고 판단에 활용한다. Q22는 판매 수량과 매출을 함께 계산하고 판매 수량 순으로 정렬한다.
3. **고객별 누적 매출 랭킹** — 우수 고객과 고객별 구매 기여도를 확인한다. Q23은 취소 주문을 제외한 고객별 구매 금액을 `RANK()`로 순위화한다.

Q21~Q23은 각각 독립 실행 가능한 최종 SQL이며, 샘플 데이터에 대한 실행 결과를 결과 텍스트에 남겼다.

## 제한 사항 준수

뷰, 프로시저, 트리거 및 백엔드 프레임워크는 사용하지 않았다. 모든 결과물은 로컬 SQLite CLI에서 실행 가능하며, 스키마 생성 순서와 부모-자식 데이터 입력 순서를 지켰다.
