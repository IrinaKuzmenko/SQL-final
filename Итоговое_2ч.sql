-------- 1	В каких городах больше одного аэропорта?	


select city as "Город", count(airport_code) as "количество аэропортов"
from airports a
group by city
having count(airport_code) > 1


-------- 2	В каких аэропортах есть рейсы, выполняемые самолетом с максимальной дальностью перелета?	- Подзапрос


select distinct f.departure_airport "Аэропорт вылета", a.city as "Город вылета", t.model "Модель самолета", count(t.aircraft_code) as "Количество самолетов", t."range" "Дальность полета км"
from (select aircraft_code, model, "range"
	from aircrafts
	order by "range" desc
	limit 1
) t
join flights f on f.aircraft_code = t.aircraft_code
join airports a on a.airport_code = f.departure_airport 
group by 1, 2, 3, 5


-------- 3	Вывести 10 рейсов с максимальным временем задержки вылета	- Оператор LIMIT

select a.city as "Город вылета", a2.city "Город назначения", f.flight_no as "Номер рейса", (f.actual_departure - f.scheduled_departure) as "Задержка вылета"
from flights f 
join airports a on a.airport_code = f.departure_airport 
join airports a2 on a2.airport_code = f.arrival_airport 
where (f.actual_departure - f.scheduled_departure) is not null
order by 4 desc
limit 10


-------- 4	Были ли брони, по которым не были получены посадочные талоны?	- Верный тип JOIN


select t.book_ref "Номер бронирования", bp.boarding_no "Номер посадочного талона"
from tickets t
left join boarding_passes bp on bp.ticket_no = t.ticket_no
where bp.boarding_no is null
group by 1, 2



-------- 5	Найдите количество свободных мест для каждого рейса, их % отношение к общему количеству мест в самолете. 
--Подзапросы или/и cte


with b as
	(select 
		f.flight_id,
		count(bp.boarding_no) as b_qty
	from flights f 
	join boarding_passes bp on bp.flight_id = f.flight_id 
	where f.actual_departure is not null
	group by f.flight_id),
	ss as 
	(select 
		a.aircraft_code, 
		count(s.seat_no) as seat_qty
	from seats s 
	join aircrafts a on a.aircraft_code = s.aircraft_code 
	group by a.aircraft_code)
select f.flight_id as "Идентификатор рейса",
		f.flight_no as "Номер рейса",
		f.departure_airport as "Аэропорт вылета",
		f.actual_departure::date as "Время вылета по факту",
		b.b_qty as "Кол-во человек на борту",
		ss.seat_qty as "Кол-во мест в самолете",
		sum(ss.seat_qty - b.b_qty) as "Кол-во свободных мест в самолете",
		round(sum(ss.seat_qty - b.b_qty)::numeric / ss.seat_qty::numeric, 2) * 100 as "% свободных мест от общего"
from flights f
join b on b.flight_id = f.flight_id 
join ss on ss.aircraft_code = f.aircraft_code
group by 1, 5, 6



-------- 6	Найдите процентное соотношение перелетов по типам самолетов от общего количества.	- Подзапрос или окно
- Оператор ROUND

select model as "Тип самолета", qty as "Кол-во перелетов", (round(qty / (sum(qty) over ()), 2) * 100) as "% от общего кол-ва перелётов"
from(
	select count(flight_id) as qty, model
	from flights f 
	join aircrafts a on a.aircraft_code = f.aircraft_code
	group by model
) l
order by 3 desc


-------- 7	Были ли города, в которые можно  добраться бизнес - классом дешевле, чем эконом-классом в рамках перелета?	- CTE



with prices as(
	select 
		a.city "Город отправления",
		a2.city "Город прибытия",
		tf.fare_conditions,
		case when tf.fare_conditions  = 'Business' then min(tf.amount) end b_min_amount,
		case when tf.fare_conditions  = 'Economy' then max(tf.amount) end e_max_amount  
	from flights f 
	join ticket_flights tf on tf.flight_id = f.flight_id 
	join airports a on f.departure_airport = a.airport_code
	join airports a2 on f.arrival_airport = a2.airport_code 
	group by 1, 2, 3
)
select
	"Город отправления", 
	"Город прибытия", 
	min(b_min_amount) "Минимум за бизнес", 
	max(e_max_amount) "Максимум за эконом"
from prices
group by 1, 2
having min(b_min_amount) < max(e_max_amount)



-------- 8	Между какими городами нет прямых рейсов?	- Декартово произведение в предложении FROM
- Самостоятельно созданные представления (если облачное подключение, то без представления)
- Оператор EXCEPT

create view cities_v as
select v.departure_city, v.arrival_city
from flights_v v

select distinct a.city, a1.city
from airports a
cross join airports a1
where a.city != a1.city
	except
select c.departure_city, c.arrival_city
from cities_v c


-------- 9	Вычислите расстояние между аэропортами, связанными прямыми рейсами, сравните с допустимой максимальной дальностью перелетов  в самолетах, обслуживающих эти рейсы *	- Оператор RADIANS или использование sind/cosd
- CASE 


select distinct a.city as "Город отправления", a2.city as "Город прибытия", 
a3.model as "Тип самолета", a3."range" as "Макс дальность полета самолета",
round(((acos((sind(a.latitude)*sind(a2.latitude) + cosd(a.latitude) * cosd(a2.latitude) * cosd((a.longitude - a2.longitude))))) * 6371)::numeric, 2) 
as "Расстояние между городами",
	case when
	a3."range" >= round(((acos((sind(a.latitude)*sind(a2.latitude) + cosd(a.latitude) * cosd(a2.latitude) * cosd((a.longitude - a2.longitude))))) * 6371)::numeric, 2)
	then 'OK'
	else 'not possible'
	end "Сравнение"
from flights f 
join airports a on a.airport_code = f.departure_airport 
join airports a2 on a2.airport_code = f.arrival_airport 
join aircrafts a3 on a3.aircraft_code = f.aircraft_code 
order by 5 desc

