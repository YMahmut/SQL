USE RESTAURANT


----kimlik numarası girilen bir calisan 1 yılını doldurdu ise zam yapan ve izin, maas ve zam bilgisini tablo olarak döndüren fonksiyon


IF OBJECT_ID('dbo.Fonk_Calisan_Izin_Maas_Zam') IS NOT NULL
	BEGIN
		DROP FUNCTION Fonk_Calisan_Izin_Maas_Zam
	END
GO

CREATE FUNCTION Fonk_Calisan_Izin_Maas_Zam(@kimlikno nvarchar(11))
RETURNS TABLE
 AS
 RETURN SELECT  	 c.CalisanAdi
					,p.PozisyonAdi
					,(cast(isnull(DATEDIFF(day, i.Izin_Baslangic_Tarihi, i.Izin_Bitis_Tarihi),0) as varchar)+'  Gün') AS [Kullanılan İzin]
					,p.Maas as eskiMaas
					,IIF((select convert(date,dateadd(month,12,ca.IseGirisTarihi),102) from Calisanlar ca where ca.KimlikNo=@kimlikno )<=convert(
						  date,getdate(),102),cast(p.Maas*1.1 as nvarchar),'zam yok') as zamliMaas
					,(dateadd(month,12,c.IseGirisTarihi)) as [Zam Yapılma Tarihi]
		FROM    dbo.Calisanlar AS c 
		INNER JOIN		 dbo.Pozisyon AS p ON c.PozisyoNo = p.PozisyonNo
		LEFT  JOIN		 dbo.Izin AS i ON c.KimlikNo = i.KimlikNo
		where c.KimlikNo=@kimlikno

go

--test1
select * from Fonk_Calisan_Izin_Maas_Zam('55510411582')
select * from Fonk_Calisan_Izin_Maas_Zam('28872297860')
