-- phpMyAdmin SQL Dump
-- version 4.0.10deb1
-- http://www.phpmyadmin.net
--

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;

--
-- Database: `koreInventory`
--
CREATE DATABASE IF NOT EXISTS `koreInventory` DEFAULT CHARACTER SET latin1 COLLATE latin1_general_cs;
USE `koreInventory`;

-- --------------------------------------------------------

--
-- Table structure for table `Accounts`
--

CREATE TABLE IF NOT EXISTS `Accounts` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `ServerIdx` int(11) NOT NULL,
  `Number` int(10) unsigned NOT NULL COMMENT 'Server assigned ID',
  `Username` varchar(30) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL,
  `Active` tinyint(1) NOT NULL,
  `Suspended` tinyint(1) NOT NULL COMMENT 'Is suspended by server',
  `SuspendUntil` datetime DEFAULT NULL COMMENT 'Date, if known',
  `Sex` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'False = male, True = female',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `ID_3` (`ID`),
  KEY `ID` (`ID`),
  KEY `ID_2` (`ID`),
  KEY `ID_4` (`ID`),
  KEY `ID_5` (`ID`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1 COLLATE=latin1_general_cs AUTO_INCREMENT=11 ;

-- --------------------------------------------------------

--
-- Table structure for table `Characters`
--

CREATE TABLE IF NOT EXISTS `Characters` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `AccountID` int(11) NOT NULL,
  `CharIdx` int(11) NOT NULL,
  `Name` varchar(30) COLLATE latin1_general_cs NOT NULL,
  `Class` varchar(30) CHARACTER SET latin1 COLLATE latin1_general_ci NOT NULL,
  `Zeny` int(11) NOT NULL COMMENT 'Shouldn''t be negative!',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `ID` (`ID`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1 COLLATE=latin1_general_cs AUTO_INCREMENT=33 ;

-- --------------------------------------------------------

--
-- Table structure for table `Items`
--

CREATE TABLE IF NOT EXISTS `Items` (
  `ID` int(11) NOT NULL,
  `Name` varchar(30) NOT NULL,
  `ItemType` int(11) NOT NULL DEFAULT '12',
  `Weight` smallint(6) NOT NULL DEFAULT '-1',
  UNIQUE KEY `ID` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COMMENT='Ideally, parsed from Items.txt ...';

-- --------------------------------------------------------

--
-- Table structure for table `ItemsInCart`
--

CREATE TABLE IF NOT EXISTS `ItemsInCart` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `CharacterID` int(11) NOT NULL COMMENT 'Idx in "Characters"',
  `ItemID` int(11) NOT NULL COMMENT 'Item ID as defined by server',
  `Count` int(11) NOT NULL DEFAULT '1',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `ID_2` (`ID`),
  KEY `ID` (`ID`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1 COMMENT='Slot entries for stored items, linked to each account' AUTO_INCREMENT=4 ;

-- --------------------------------------------------------

--
-- Table structure for table `ItemsInInventory`
--

CREATE TABLE IF NOT EXISTS `ItemsInInventory` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `CharacterID` int(11) NOT NULL,
  `ItemID` int(11) NOT NULL COMMENT 'Item ID as defined by server',
  `Count` int(11) NOT NULL DEFAULT '1',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `ID_2` (`ID`),
  KEY `ID` (`ID`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1 COMMENT='Slot entries for stored items, linked to each account' AUTO_INCREMENT=5 ;

-- --------------------------------------------------------

--
-- Table structure for table `ItemsInStorage`
--

CREATE TABLE IF NOT EXISTS `ItemsInStorage` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `AccountID` int(11) NOT NULL,
  `StorageIdx` tinyint(3) unsigned NOT NULL DEFAULT '1' COMMENT '1..Accounts.StorageNum-1',
  `ItemID` int(11) NOT NULL COMMENT 'Item ID as defined by server',
  `Count` int(11) NOT NULL DEFAULT '1',
  PRIMARY KEY (`ID`),
  UNIQUE KEY `ID_2` (`ID`),
  KEY `ID` (`ID`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1 COMMENT='Slot entries for stored items, linked to each account' AUTO_INCREMENT=4 ;

-- --------------------------------------------------------

--
-- Table structure for table `ItemTypes`
--

CREATE TABLE IF NOT EXISTS `ItemTypes` (
  `Type` int(11) NOT NULL,
  `Name` varchar(15) NOT NULL,
  UNIQUE KEY `Type` (`Type`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COMMENT='From /tables/itemtypes.txt';

--
-- Dumping data for table `ItemTypes`
--

INSERT INTO `ItemTypes` (`Type`, `Name`) VALUES
(0, 'Usable Heal'),
(1, 'Usable Status'),
(2, 'Usable Special'),
(3, 'Event'),
(4, 'Armor'),
(5, 'Weapon'),
(6, 'Card'),
(7, 'Quest'),
(8, 'Pet Armor'),
(9, '2-Hand Weapon'),
(10, 'Arrow'),
(11, 'Helmet'),
(12, 'Unknown_Type_12'),
(13, 'Mask'),
(14, 'Headgear'),
(15, 'Gun'),
(16, 'Ammo'),
(17, 'Shuriken'),
(18, 'Cash Item'),
(19, 'Cannonball'),
(20, 'Costume');

-- --------------------------------------------------------

--
-- Table structure for table `ItemValues`
--

CREATE TABLE IF NOT EXISTS `ItemValues` (
  `ID` int(11) NOT NULL,
  `Cost` int(11) NOT NULL DEFAULT '0',
  `Wholesale` int(11) NOT NULL DEFAULT '0',
  `Retail` int(11) NOT NULL DEFAULT '0',
  `NPCBuy` int(11) NOT NULL DEFAULT '0',
  `NPCSell` int(11) NOT NULL DEFAULT '0',
  UNIQUE KEY `ID_2` (`ID`),
  KEY `ID` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COMMENT='Defines value of an item. for calculating net worth.';

-- --------------------------------------------------------

--
-- Table structure for table `Servers`
--

CREATE TABLE IF NOT EXISTS `Servers` (
  `ID` int(11) NOT NULL,
  `Name` varchar(48) COLLATE latin1_general_cs NOT NULL,
  `StorageNum` tinyint(3) unsigned NOT NULL DEFAULT '1',
  `StorageSlots` smallint(5) unsigned NOT NULL,
  `InventorySlots` smallint(5) unsigned NOT NULL,
  `CartSlots` smallint(5) unsigned NOT NULL,
  UNIQUE KEY `ID_2` (`ID`),
  KEY `ID` (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_general_cs;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
