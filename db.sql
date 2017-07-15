/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `stats` (
      `steamid` varchar(50) NOT NULL,
      `name` varchar(50) DEFAULT NULL,
      `kills` int(11) DEFAULT '0',
      `tks` int(11) DEFAULT '0',
      `knifed` int(11) DEFAULT '0',
      `got_knifed` int(11) DEFAULT '0',
      `sips` int(11) DEFAULT '0',
      `rounds` int(11) DEFAULT '0',
      PRIMARY KEY (`steamid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;
