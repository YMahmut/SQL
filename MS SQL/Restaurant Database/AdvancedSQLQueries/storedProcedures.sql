/* İÇİNDEKİLER

	1.UPDATE SP
	2.TRIGGER
	3.DELET SP
	-View       : Cursor da kullanıldı.
	4.CURSOR
	5.SELECT SP
	6.INSERT SP
	7.TRANSCTION SP
*/


USE RESTAURANT

--SP : yemek fiyatlarını guncelleyen (tercihe göre) indirim veya zam yapan  sp .İndirim mi Fiyat artışı mı yapılacağı parametre ile kararlaştırılıyor (UPDATE SP)


IF OBJECT_ID('dbo.sp_FiyatGuncelle') IS NOT NULL
	BEGIN
		DROP PROCEDURE sp_FiyatGuncelle
	END
GO
create PROCEDURE sp_FiyatGuncelle
	
	@degisiklik_oranı money,
	@degisiklik_bilgisi varchar(30)
as
begin
	if @degisiklik_bilgisi='zam'
			begin
			update Yemek
			set	
				BirimFiyati=round((BirimFiyati*(1+@degisiklik_oranı)),1)
					
			select top(1)'yemek fiyatlarına %'+ cast((@degisiklik_oranı*100) as nvarchar(100))+ ' zam yapıldı'  from Yemek y
				inner join YemekCesit yc on y.YemekCesitNo=yc.YemekCesitNo
				
			end
	else if @degisiklik_bilgisi='indirim'
			begin
			update Yemek
			set
				BirimFiyati=round((BirimFiyati*(1-@degisiklik_oranı)),1)
									 
			select top(1) 'yemek fiyatlarına %'+ cast((@degisiklik_oranı*100) as nvarchar(100))+ ' indirim yapıldı'  from Yemek y
				inner join YemekCesit yc on y.YemekCesitNo=yc.YemekCesitNo
			end
				
	else
		begin
		print 
		'		fiyatları arttırmak için 3.parametere olarak  "ZAM" yazın
				
		indirim uygulamak için 3. parametre olarak "indirim" yazın '
		end
end
go
---test   
select * from Yemek--GÜNCELLEME öncesi
go
EXEC dbo.sp_FiyatGuncelle @degisiklik_oranı=0.10
						  ,@degisiklik_bilgisi='indirim'   --veya 'zam'
GO
select * from Yemek--GÜNCELLEME sonrası

GO

---------------------------------------------------------------------------
--trigger   
-- yemek fiyatlarındaki fiyat artış durumunda, yemeklere talep azalır, bunun sonucunda üretim stoklarını azaltılarak zarar önlenmeye çalışılır,
-- indirim durumunda ise stok miktarını arttırarak talep ihtiyacı karşılanmaya çalışılır 

IF OBJECT_ID('dbo.tg_Piysaya_gore_Uret ') IS NOT NULL
	BEGIN
		DROP TRIGGER tg_Piysaya_gore_Uret 
	END
GO
create trigger tg_Piysaya_gore_Uret on Yemek 
after update as
begin
--eski tablo fiyatları
declare @eski_fiyat_toplami money;
 declare @eski_fiyat_tablosu table(birim_fiyat money);
 insert into @eski_fiyat_tablosu
 select  BirimFiyati from deleted       --güncellenme öncesi veriler DELETED tablosundan alınıyor
 set @eski_fiyat_toplami= (select sum(birim_fiyat) from @eski_fiyat_tablosu)
 --yeni tablo fiyatları
 declare @yeni_fiyat_toplami money;
 declare @yeni_fiyat_tablosu table(birim_fiyat money);
 insert into @yeni_fiyat_tablosu
 select  BirimFiyati from inserted      --güncellenme sonrası veriler INSERTED tablosundan alınıyor
 set  @yeni_fiyat_toplami=(select sum(birim_fiyat) from @yeni_fiyat_tablosu)

 if  @yeni_fiyat_toplami>@eski_fiyat_toplami
	 begin
	 update Yemek set Stok=Stok-(round(Stok/5,0))
	 select    ' fiyat artışı nedeniyle satışlar düşbilir. Bu nedenle stoklar azaltıldı'
	 end
 else if  @yeni_fiyat_toplami<@eski_fiyat_toplami
	 begin
	 update Yemek set Stok=Stok+(round(Stok/5,0))
	  select   ' fiyat indirimi nedeniyle satışlar artabilir. Bu nedenle stoklar arttırıldı'
	 end
 else
	  select   ' fiyatlar değişmedi. azalan stokların üretimi dışında stoklarda değişiklik yok'
end

select * from Yemek
go

--test 
--update sp ile trigger'ı test ediyoruz
exec dbo.sp_FiyatGuncelle 0.1,'indirim'---veya indirim yerine 'zam'
go
select * from Yemek



GO


---------------------------------------------------------------------------------------------
--SP   İncelenen bir zaman aralağında hiç satılmayan icecekleri satış menüsünden kaldıran sp :(DELETE SP)
 --örnğin 1 numaralı içecek çeşitlerinden son bir ay içerisinde hiç satılmayanları menümüzden silelim 

IF OBJECT_ID('dbo.sp_Satılmayan_urunu_sil') IS NOT NULL
	BEGIN
		DROP PROCEDURE sp_Satılmayan_urunu_sil
	END
GO
create PROCEDURE sp_Satılmayan_urunu_sil
@icecekcesidi int,			--satilmiyan ürünlerin inceleneceği içecek çeşidi ve tarih aralıkları parametre olarak veriliyor
@surec_baslangici date,
@surec_bitisi date
as
begin
	delete from Icecek
		where IcecekAdi=(
					select IcecekAdi from Icecek
					where IcecekCesitNo=@icecekcesidi
				except
				select distinct IcecekAdi from Icecek i
					inner join SiparisIcecekDetay sidty on i.IcecekNo=sidty.IcecekNo
						inner join Siparisler s         on sidty.SiparisNo=s.SiparisNo
					where (s.SiparisTarihi between  @surec_baslangici and @surec_bitisi ) 
					and i.IcecekCesitNo=@icecekcesidi
						)
end

-----------------spDelete TESTİ
 -- Öncelikle bu kod parçası ile girilen tarih değerleri arasında hiç sipariş edilmemiş içecek var mı bakılabilir SONRASINDA final test'i yapılır 
	select T.IcecekNo, Icecek.IcecekAdi, Icecek.IcecekCesitNo, Icecek.BirimFiyati
	 from	(	select i.IcecekNo from Icecek i
				except
				select syd.IcecekNo from SiparisIcecekDetay syd
				inner join Siparisler s 
					on syd.SiparisNo=s.SiparisNo
				where (s.SiparisTarihi between '2019-12-20'and '2020-11-20' )
			)T
	inner join Icecek on t.IcecekNo=Icecek.IcecekNo
	
	go
	
-- final test => yukarıda tespit edilen içecek çeşidi no ve tarih girilmelidir
select * from Icecek--delete öncesi

EXEC dbo.sp_Satılmayan_urunu_sil  @icecekcesidi=2
								  ,@surec_baslangici= '2019-12-20'
								  ,@surec_bitisi= '2020-11-20'
								  
select * from Icecek--delete sonrası


GO


-------------------------------------------------------------------------------------------------

---Müşterilerin sipariş detaylarını toplam ödeme tutarını da oluşturararak gösteren view.
-- Test kısmında view kullanılarak müşteriyi,müşterinin siparişte bulunduğu restoranı, sipariş tarihini ve toplam ödeme tutarıyla birlikte neler sipariş --ettiği gösteriliyor. 

IF OBJECT_ID('dbo.view_Musteri_Siparis_Bilgisi ') IS NOT NULL
	BEGIN
		DROP VIEW view_Musteri_Siparis_Bilgisi
	END
GO
create view [dbo].[view_Musteri_Siparis_Bilgisi] as
SELECT        m.MusteriNo, s.SiparisNo,s.KimlikNo,
 ISNULL(y.YemekAdi, '-') AS yemek, ISNULL(i.IcecekAdi, '-') AS icecek, ISNULL(t.TatliAdi, '-') AS tatli,
 ISNULL(y.BirimFiyati, 0)  + ISNULL(i.BirimFiyati, 0)+ ISNULL(t.BirimFiyati, 0) AS ToplamTutar
FROM	 dbo.Musteriler AS m 
					INNER JOIN dbo.Siparisler AS s ON s.MusteriNo = m.MusteriNo 
					LEFT OUTER JOIN dbo.SiparisIcecekDetay AS sdi ON s.SiparisNo = sdi.SiparisNo 
				    LEFT OUTER JOIN dbo.SiparisYemekDetay AS sdy ON s.SiparisNo = sdy.SiparisNo 
					LEFT OUTER JOIN dbo.SiparisTatliDetay AS sdt ON s.SiparisNo = sdt.SiparisNo 
				    LEFT OUTER JOIN dbo.Yemek AS y ON sdy.YemekNo = y.YemekNo 
				    LEFT OUTER JOIN dbo.Icecek AS i ON sdi.IcecekNo = i.IcecekNo 
					LEFT OUTER JOIN dbo.Tatli AS t ON sdt.TatliNo = t.TatliNo

GO


-------------------------------------------------------------------------------------------------

--SP  :Verilen parametreleri ve bir cursor’ü kullanarak veritabanında her hangi bir işlemi (insert, update, delete, select) yerine getirmeli (CURSOR SP)

--Aylık, haftalık veya günlük olabileceği gibi; başlangıç ve bitiş tarihleri  verilen  herhangi bir zaman aralığı için her bir şubenin yaptığı ciroyu gösteren CURSOR SP


IF OBJECT_ID('dbo.proc_Sube_Cirolari') IS NOT NULL
	BEGIN
		DROP PROCEDURE proc_Sube_Cirolari
	END
GO
create PROCEDURE proc_Sube_Cirolari
@baslangic_tarihi date,
@bitis_tarihi date
as
begin

DECLARE @SubeAdi VARCHAR(100), @toplam_ciro money;

DECLARE Cursor_Subelerin_Cirosu CURSOR FOR select s.SubeAdi, sum(ms.ToplamTutar) toplam_ciro
 from dbo.view_Musteri_Siparis_Bilgisi ms
      inner join Calisanlar c on ms.KimlikNo=c.KimlikNo
            inner join Subeler s on c.SubeNo=s.SubeNo
	inner join Siparisler sip on ms.SiparisNo=sip.SiparisNo
 where sip.SiparisTarihi between @baslangic_tarihi and @bitis_tarihi
 group by s.SubeAdi
OPEN Cursor_Subelerin_Cirosu;
FETCH NEXT FROM Cursor_Subelerin_Cirosu INTO @SubeAdi,@toplam_ciro;
WHILE @@FETCH_STATUS=0
BEGIN
	print @SubeAdi+'	Şubesi Cirosu	'+convert(nvarchar,@toplam_ciro)+' Lira';
	FETCH NEXT FROM Cursor_Subelerin_Cirosu INTO @SubeAdi,@toplam_ciro;
END;
CLOSE Cursor_Subelerin_Cirosu;
DEALLOCATE Cursor_Subelerin_Cirosu;
end
go
--test
exec proc_Sube_Cirolari     @baslangic_tarihi='2020-10-01',   @bitis_tarihi='2020-11-01'

GO

-------------------------------------------------------------------------------------

--SP  : Verilen parametrelere göre sorgulama işlemi yapmalı (SELECT SP)

--müşteri istediği çeşidin numarasını girince o çeşitlerin içinden fiyatı en uygun olan 5 adet Yemek,İçecek ve Tatlılardan fiyatıyla birlikte menüler --oluşturan sp

IF OBJECT_ID('dbo.sp_EN_UYGUN_MENU ') IS NOT NULL
	BEGIN
		DROP  PROCEDURE sp_EN_UYGUN_MENU 
	END
GO
create PROCEDURE sp_EN_UYGUN_MENU 
@yemekcesidi int,
@icecekcesidi int,
@tatlicesidi int
as
begin
if (@yemekcesidi in (1,2,3,4,6,7,9,10) and @icecekcesidi in (1,2,3,4) and @tatlicesidi in(1,2,3))
begin
declare @k int=1,@c int=0
declare @Uygun_Menu table(YEMEK nvarchar(50),CORBA nvarchar(50),SALATA nvarchar(50),ICECEK nvarchar(50),TATLI nvarchar(50),ToplamTutar money)
while @k<6
	begin
	set @k=@k+1
	insert into @Uygun_Menu
		select distinct ( select YemekAdi from Yemek  
							where YemekCesitNo=@yemekcesidi order by BirimFiyati OFFSET @c ROWS FETCH NEXT 1 ROWS ONLY )as yemekler,
						(select YemekAdi  from Yemek
							where YemekCesitNo=5 order by BirimFiyati OFFSET @c rows fetch next 1 rows only)as Corbalar,
						(select YemekAdi  from Yemek
							where YemekCesitNo=8 order by BirimFiyati offset @c rows fetch next 1 rows only)as salatalar,
						(select IcecekAdi from Icecek i
							where i.IcecekCesitNo=@icecekcesidi order by i.BirimFiyati offset @c rows fetch next 1 rows only) as icecekler, 
						(select t.TatliAdi from Tatli t
							where t.TatliCesitNo=@tatlicesidi order by t.BirimFiyati offset @c rows fetch next 1 rows only )as tatlilar,
							--tutar hesabı burdan sonra yapılıyor
					    (   isnull(( select BirimFiyati from Yemek  
							where YemekCesitNo=@yemekcesidi order by BirimFiyati OFFSET @c ROWS FETCH NEXT 1 ROWS ONLY ),0)+
							isnull((select BirimFiyati  from Yemek
							where YemekCesitNo=5 order by BirimFiyati OFFSET @c rows fetch next 1 rows only),0)+
							isnull((select BirimFiyati  from Yemek
							where YemekCesitNo=8 order by BirimFiyati offset @c rows fetch next 1 rows only),0)+
							isnull((select i.BirimFiyati from Icecek i
							where i.IcecekCesitNo=@icecekcesidi order by i.BirimFiyati offset @c rows fetch next 1 rows only),0)+
							isnull((select t.BirimFiyati from Tatli t
							where t.TatliCesitNo=@tatlicesidi order by t.BirimFiyati offset @c rows fetch next 1 rows only ),0)) as toplamTutar
		from Yemek y
		inner join SiparisYemekDetay syd on y.YemekNo=syd.YemekNo
		inner join Siparisler s on syd.SiparisNo=s.SiparisNo
		inner join SiparisIcecekDetay sicd on s.SiparisNo=sicd.SiparisNo
		inner join Icecek i on sicd.IcecekNo=i.IcecekNo
		inner join SiparisTatliDetay std on s.SiparisNo=std.SiparisNo
		inner join Tatli t on std.TatliNo=t.TatliNo
	set @c=@c+1
	end
 select * from @Uygun_Menu
 end
 else
 print 'Aşağıdaki numaralar dışında menü oluşturamazsınız
  yemek secenekleri :
			deniz ürünlri = 1	,	kebaplar = 2		,	tavuk yemekleri = 3	,	bakliyat yemekleri = 4
			zeytinyağlılar = 6	,	sebze yemeklri = 7	,	fastfood = 9		,	kahvaltı = 10 
	
  icecek secenekleri için :
			kahve = 1			,	çay = 2				,		hoşaf = 3		,	soğuk içecekler = 4 
				
  tatlı secenekleri için :
			şerbetli = 1		,	sütlü = 2			,		pasta = 3 '
 end
 go
 --test 
 exec dbo.sp_EN_UYGUN_MENU @yemekcesidi=3
						  ,@icecekcesidi=2
						  ,@tatlicesidi=1
 

 GO
 -------------------------------------------------------------------------------------------

 --SP : yıllık izin süresini doldurmamış olanalara izin vererek izin tablosuna ekleyen sp (INSERT SP)

IF OBJECT_ID('dbo.sp_Calisan_izni_Ekle') IS NOT NULL
	BEGIN
		DROP PROCEDURE sp_Calisan_izni_Ekle
	END
GO
create PROCEDURE sp_Calisan_izni_Ekle
(
-- @izin_no int	,		   --izin numaralarının aynı değer verilmesini önlemek için sorgu ile eklendi.
@izin_Baslangic_Tarihi date,
@izin_Bitis_Tarihi date,
@kimlik_No nvarchar(11))
as
begin
	declare @izin_Onay nvarchar(15);      --izin verilsin mi verilmesin mi?
	declare @yapilan_iznin_gun_sayisi int; --çalışan izin istediği yıl içerisinde toplam ne kadar izin yapmış.
	set @yapilan_iznin_gun_sayisi=
			isnull((
			select datediff(day,i.Izin_Baslangic_Tarihi,i.Izin_Bitis_Tarihi) as yapilan_iznin_gun_sayisi
			from Izin i 
			 where KimlikNo=@kimlik_No
			  and year(i.Izin_Baslangic_Tarihi)=year(@izin_Baslangic_Tarihi)
		       		 ),0)
	if	@yapilan_iznin_gun_sayisi between 0 and 19	---yıllk izin süresini doldurmamışsa izin verelim (toplam yıllık izin 20 gün)
			set @izin_Onay='ONAY VERILDI';
	else								---yeterince izin yapmış yeni izin yok
			set @izin_Onay='ONAY VERILMEDI'; 
	if @izin_Onay='ONAY VERILDI'
		begin
			declare @izin_No int= (select max(İzinNo )+1 from Izin)  --izin numarası değerinin atanması
			/*  bir  onceki satirda max yerine count fonksiyonu kullansaydım veya select ifadesinden sonra 
			 @@rowcount kullansaydım izin tablosundan son satırdan önceki herhangi bir satırı silmem durumunda
			 bu prosedür çalıştığında  PK hatası verirdi.bu nedenle max fonksiyonu kullandım    */

			declare @istenilen_izin_gun_sayisi int=(datediff(day,@izin_Baslangic_Tarihi,@izin_Bitis_Tarihi))
			
			--! AMA önceden izin yaptıysa KALAN izin günü kadar izin veriliyor.												
			if(@istenilen_izin_gun_sayisi)>(20-@yapilan_iznin_gun_sayisi) 
			set @izin_Bitis_Tarihi=(SELECT DATEADD(day,(20-@yapilan_iznin_gun_sayisi),@izin_Baslangic_Tarihi))

			/*hiç izin yapmamışsa veya yıllık izin süresini doldurmayacak şekilde ikinci defa izin kullanacaksa 
			 izin bitiş tarihi parametre olarak geldiği haliyle ekleniyor */
			insert into
					Izin ( İzinNo, Izin_Baslangic_Tarihi, Izin_Bitis_Tarihi, KimlikNo )
					 values ( @izin_No, @izin_Baslangic_Tarihi, @izin_Bitis_Tarihi, @kimlik_No)
		 end
	 else 
			print 'Bu çalışan yeterince izin yaptığı için yeni izin kaydı OLUŞTURULMADI !'
end

go
-------------------insert testi

------------test kolaylığı olması için son parametre olan kimlik_No'yu elde etmeyi sağlayan aşağıdaki değişkenler oluşturuldu.
select * from Izin --ekleme öncesi

go
 /*HİÇ İZİN YAPMAMIŞ RASTGELE SEÇİLEN BİR ÇALIŞANIN KİMLİK NO'SU */
declare @hic_izin_yapmamis_calisan nvarchar(11)=(select top(1) c.KimlikNo from Izin i
												  right join Calisanlar c on i.KimlikNo=c.KimlikNo
												   where i.İzinNo is NULL
													order by newid()); 
/*İZNİNİ KISMEN KULLANMIŞ RASTGELE SEÇİLEN BİR ÇALIŞANIN KİMLİK NO'SU */
declare @izin_yapmis_ama_BITIRMEMIS_calisan nvarchar(11)=(select top(1) i.KimlikNo from Izin i
													where datediff(day,i.Izin_Baslangic_Tarihi,i.Izin_Bitis_Tarihi) between 1 and 19
													order by newid());
/*İZNİNİ TAMAMEN KULLANMIŞ RASTGELE SEÇİLEN BİR ÇALIŞANIN KİMLİK NO'SU */
declare @iznini_tamamlamis_calisan nvarchar(11)=(select top(1) i.KimlikNo from Izin i
													where datediff(day,i.Izin_Baslangic_Tarihi,i.Izin_Bitis_Tarihi)>=20
													order by newid());          

EXEC dbo.sp_Calisan_izni_Ekle 
		@izin_Baslangic_Tarihi='2021-02-01',
		@izin_Bitis_Tarihi='2021-02-19',
		@kimlik_No = @hic_izin_yapmamis_calisan --veya @iznini_tamamlamis_calisan  veya  @hic_izin_yapmamis_calisan
go
select * from Izin--ekleme sonrası


GO

-------------------------------------------------------------------------------------------
				--transaction     
/*
  Bir şube'nin aynı pozisyonunda bulunan 2 farklı çalışanın izinlerinin aynı tarihe gelmesini engelleyen transaction
 */


--


IF OBJECT_ID('dbo.sp_Calisan_izni_Ekle_tran') IS NOT NULL
	BEGIN
		DROP PROCEDURE sp_Calisan_izni_Ekle_tran
	END
GO
create PROCEDURE sp_Calisan_izni_Ekle_tran
(
@izin_Baslangic_Tarihi date,
@izin_Bitis_Tarihi date,
@kimlik_No nvarchar(11))
as
begin
SET NOCOUNT ON
begin tran
	declare @pz_num int=( select   PozisyoNo from Calisanlar where  KimlikNo = @kimlik_No);
	declare	@sb_num int =( select   SubeNo from Calisanlar where  KimlikNo = @kimlik_No) ;
			---ekleme öncesinde izin tablosunda önceden oluşturulmuş izinlerden aynı sube ve pozisyonda olanlar bulunuyor.
	declare @tablo1 table(iz_no int  ,pzsyn_num int, sub_num int,   iz_bas_trh date,      iz_bit_trh date) 
	insert into @tablo1
			 select   i.İzinNo  ,c.PozisyoNo,     c.SubeNo, i.Izin_Baslangic_Tarihi, i.Izin_Bitis_Tarihi
			 from Calisanlar c
				inner join Izin i on i.KimlikNo=c.KimlikNo
			 where c.PozisyoNo=@pz_num and c.SubeNo=@sb_num

	declare @izin_Onay nvarchar(12);    
	declare @yapilan_iznin_gun_sayisi int; 
	set @yapilan_iznin_gun_sayisi=
			isnull((
			select datediff(day,i.Izin_Baslangic_Tarihi,i.Izin_Bitis_Tarihi) as yapilan_iznin_gun_sayisi
			from Izin i 
			 where KimlikNo=@kimlik_No
			  and year(i.Izin_Baslangic_Tarihi)=year(@izin_Baslangic_Tarihi)
		       		 ),0)
	if	@yapilan_iznin_gun_sayisi between 0 and 19	
			set @izin_Onay='ONAY VERILDI';
	declare  @izin_ekleme_sonuc nvarchar(13); 
	if @izin_Onay='ONAY VERILDI'
		begin
			declare @izin_No int= (select max(İzinNo )+1 from Izin) 

			declare @istenilen_izin_gun_sayisi int=(datediff(day,@izin_Baslangic_Tarihi,@izin_Bitis_Tarihi))
															
			if(@istenilen_izin_gun_sayisi)>(20-@yapilan_iznin_gun_sayisi) 
			set @izin_Bitis_Tarihi=(SELECT DATEADD(day,(20-@yapilan_iznin_gun_sayisi),@izin_Baslangic_Tarihi))
			insert into
					Izin ( İzinNo, Izin_Baslangic_Tarihi, Izin_Bitis_Tarihi, KimlikNo )
					 values ( @izin_No, @izin_Baslangic_Tarihi, @izin_Bitis_Tarihi, @kimlik_No)
			set @izin_ekleme_sonuc='KAYIT EKLENDI'
		 end
	else 
			print 'Bu çalışan yeterince izin yaptığı için yeni izin kaydı OLUŞTURULMADI !'

    --------Yukarda baslatılan Transaction'un, insert stored prosedurune ek olarak yaptigi Cakisma Kontrolü burdan itibaren basliyor
	
	if @izin_ekleme_sonuc='KAYIT EKLENDI'
		begin
			declare @tablo_yeni_izin table(iz_no int  ,pzsyn_num int, sub_num int,   iz_bas_trh date,      iz_bit_trh date) ;
			insert into @tablo_yeni_izin
				select   i.İzinNo  ,c.PozisyoNo,     c.SubeNo, i.Izin_Baslangic_Tarihi, i.Izin_Bitis_Tarihi
				from Calisanlar c
				inner join Izin i on i.KimlikNo=c.KimlikNo
				where i.İzinNo=@izin_no
			--bu yeni iznin tüm günleri bulunup sube ve pozisyon bilgisi de barındırılmak üzere bir tabloya kaydedildi.
      
			declare @temp1 int;
			set @temp1=0;
			while @temp1<=(select datediff(day,iz_bas_trh,iz_bit_trh) gun_sayisi from @tablo_yeni_izin)
				begin
					declare @tablo_yeni_kiyaslama_tablosu table(pzsyn_num int, sub_num int,   gunler date ) 
					insert into @tablo_yeni_kiyaslama_tablosu
						select  pzsyn_num, sub_num, dateadd(day,@temp1,iz_bas_trh) as gunler
						from @tablo_yeni_izin
					set @temp1=@temp1+1;
				end

			--daha sonra kesişimi incelereken kullanılmak üzere tablo ve int degiskeni hazırlandı.
			declare @kesisen_gun_sayisi int=0,
					@kesisen_kisi_sayisi int=0;
			---izinler kimlerin izniyle kesişiyor bir tabloya atmak ve göstermek için.
			declare	@tablo_izni_kesisenler  table(kesisen_izin_numarasi int,kesisen_gun_sayisi int)

			--aynı sube ve pozisyondaki izinler inceleniyor.birer birer izin günleri bulunup bir tabloya atanıyor ve yeni izin ile kıyaslanıyor.

			while (select count(*) from @tablo1) >0
				begin
					declare @tablo2 table(iz_no int  ,pzsyn_num int, sub_num int,   iz_bas_trh date,      iz_bit_trh date) 
					insert into @tablo2
						select top(1) * from @tablo1 

					declare @temp int;
					set @temp=0;
					while @temp<=(select datediff(day,iz_bas_trh,iz_bit_trh) gun_sayisi from @tablo2)
					begin
						declare @tablo3 table(pzsyn_num int, sub_num int,   gunler date ) 
						insert into @tablo3
							select  pzsyn_num, sub_num, dateadd(day,@temp,iz_bas_trh) as gunler
							from @tablo2

						set @temp=@temp+1;
						---intersect kullanarak kesişen gün var mı diye bakıp, varsa kaç gün var? kaç farklı kişiyle kesişim var, sorgulanıyor.
						set @kesisen_gun_sayisi=(select count(*)from
													(	select * from @tablo3
															intersect
														select * from @tablo_yeni_kiyaslama_tablosu)  T	
												)
					end

					if @kesisen_gun_sayisi>0
						begin
							set @kesisen_kisi_sayisi=@kesisen_kisi_sayisi+1;   ---rollback yapmak için kullanılabilir ve kesişen izinler tablosunu göstermeden önce önce bilgi olarak da sunulabilir
							insert into @tablo_izni_kesisenler (kesisen_izin_numarasi ,kesisen_gun_sayisi )
								values  ((select iz_no from @tablo2 ),@kesisen_gun_sayisi);
							set @kesisen_gun_sayisi=0;
							delete from @tablo3;
						end
					delete from @tablo1 where iz_no=(SELECT top(1) iz_no FROM @tablo1)
					delete from @tablo2;
	
				end
				if @kesisen_kisi_sayisi >0
				begin
					rollback tran;
					select  'IZIN OLUSTURULMADI !!  Bu tarihlerde izinli olan  '+ cast(@kesisen_kisi_sayisi as nvarchar(100))+' adet personel var' AS BILGI;
					
					select ik.kesisen_izin_numarasi AS [Cakisan Izin No],c.CalisanAdi+' '+c.CalisanSoyadi as[Izinli Personel],ik.kesisen_gun_sayisi[Cakisan Gun Sayisi] from @tablo_izni_kesisenler ik
					inner join Izin i on ik.kesisen_izin_numarasi=i.İzinNo
					inner join Calisanlar c on i.KimlikNo=c.KimlikNo
				end
				else
				begin
					commit tran;
					print 'IZIN BASARIYLA EKLENDI'

				end
	end
	  --izinini tamamlamis kisilerde izin olusturma kaydi eklenmeyecegi icin if blogu calismasina gerek kalmiyor. Bu durumda ise baslatılan transaction acik kalmamasi için burda kapatılıyor. 
	else
		rollback tran; 
end

go
-------------------Transaction testi


select * from Izin   --ekleme öncesi

go
EXEC dbo.sp_Calisan_izni_Ekle_tran 
		@izin_Baslangic_Tarihi='2020-08-25',
		@izin_Bitis_Tarihi='2020-09-10',
		@kimlik_No = '86065894969'
go
select * from Izin  --ekleme sonrası
GO
		
