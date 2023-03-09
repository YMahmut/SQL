USE RESTAURANT

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


--view testi
select  m.MusteriAd + ' ' + m.MusteriSoyad as [Müşteri AdıSoyadı],	su.SubeAdi+' Şubesi' as Restoran,	
		convert(varchar(25),s.SiparisTarihi,106) as [Sipariş Tarihi],	
		v_msb.yemek,	v_msb.icecek,	v_msb.tatli,	v_msb.ToplamTutar,	 o.OdemeTipi
 from view_Musteri_Siparis_Bilgisi as v_msb
 inner join Calisanlar as c on v_msb.KimlikNo=c.KimlikNo
 inner join Musteriler as m on v_msb.MusteriNo=m.MusteriNo
 inner join Siparisler as s on v_msb.SiparisNo=s.SiparisNo
 inner join Odeme as o on o.OdemeNo = s.OdemeNo
 inner join Subeler as su on c.SubeNo=su.SubeNo
 order by Restoran
 
 GO
