USE RESTAURANT
---------------------------------------------------------------------

				--Musteriler tablosuna 50000 kayıt ekleme kodu.    Performans ölçümünü kolaylaştırmak için hazırlandı.

declare @mytable table(mustrno int,mustrad nvarchar(30) , soyd nvarchar(30), tel nvarchar(30),mail nvarchar(30))
declare @mustrno int=(select max(MusteriNo) from Musteriler), @sayac int=50000
while @sayac>0
begin
declare @tel nvarchar(30)='',@mustrad nvarchar(30)='',@soyd nvarchar(30)='',@mustrMail nvarchar(30)='',@sayac2 int=0

set @mustrno=@mustrno+1
while @sayac2<10
begin
	set @mustrad=concat(@mustrad,char(round(rand()*25,0)+65))
	set @soyd=concat(@soyd,char(round(rand()*25,0)+65))
	set @tel =concat(@tel,cast((round(rand()*8,0)+1) as varchar))
	set @sayac2=@sayac2+1
end
set @mustrMail =concat(@mustrad,'@hotmail')
set @sayac = @sayac - 1

insert into  Musteriler
values(@mustrno,@mustrad,@soyd,@tel,@mustrMail)
end
update Musteriler set MusteriAd='Emre',MusteriSoyad='Fourier',MusteriEmail='emrefori@hotmail.com' where MusteriNo=84;
update Musteriler set MusteriAd='Emre' where MusteriNo%597=0;
select * from Musteriler

---------------------------------------------------------------------------
GO



--- müştrilerin numarasını hatırlamanın zor olması nedeniyle, isimle yapılacak aramaları hızlandırmak için kullanılan İNDEX


----------------------------------------------------------------------------


IF EXISTS (SELECT *  FROM sys.indexes  WHERE name='indx_Musterilerin_adlari'  AND object_id = OBJECT_ID('[dbo].[Musteriler]'))
  begin
    DROP INDEX [indx_Musterilerin_adlari] ON [dbo].[Musteriler];
  end



----------------------------------------------------------------------------

GO
select * from Musteriler where MusteriAd='Emre' and MusteriSoyad='Fourier'        --INDEX ONCESI		
GO



----------------------------------------------------------------------------------


CREATE NONCLUSTERED INDEX indx_Musterilerin_adlari
ON Musteriler(MusteriAd) WITH(pad_index=on, fillfactor=90, drop_existing=off)
go


------------------------------------------------------------------------------------


select * from Musteriler where MusteriAd='Emre' and MusteriSoyad='Fourier'         --INDEX SONRASI
