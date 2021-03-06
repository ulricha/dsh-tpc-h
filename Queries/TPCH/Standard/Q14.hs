{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE GADTs                 #-}
{-# LANGUAGE MonadComprehensions   #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE RebindableSyntax      #-}
{-# LANGUAGE TemplateHaskell       #-}
{-# LANGUAGE TypeFamilies          #-}
{-# LANGUAGE UndecidableInstances  #-}
{-# LANGUAGE ViewPatterns          #-}

-- | TPC-H Q14
module Queries.TPCH.Standard.Q14
    ( q14
    , q14a
    , q14Default
    , q14aDefault
    ) where

import qualified Data.Time.Calendar as C
import Database.DSH
import Schema.TPCH


-------------------------------------------------------------------------------

-- | TPC-H Query Q14 with standard validation parameters
q14Default :: Q Decimal
q14Default = q14 (C.fromGregorian 1995 9 1)

-- | TPC-H Query Q14 with standard validation parameters (alternative
-- formulation)
q14aDefault :: Q Decimal
q14aDefault = q14a (C.fromGregorian 1995 9 1)

-------------------------------------------------------------------------------

revenue :: Q Decimal -> Q Decimal -> Q Decimal
revenue ep dis = ep * (1 - dis)

itemPrices :: Day -> Q [(Text, Decimal, Decimal)]
itemPrices startDate =
  [ tup3 (p_typeQ p) (l_extendedpriceQ l) (l_discountQ l)
  | l <- lineitems
  , p <- parts
  , l_partkeyQ l == p_partkeyQ p
  , l_shipdateQ l >= toQ startDate
  , l_shipdateQ l < toQ (C.addDays 30 startDate)
  ]

-------------------------------------------------------------------------------
-- Literal transcription of the TPC-H benchmark query

q14 :: Day -> Q Decimal
q14 startDate = 100.0 * promoRev / totalRev
  where

    promoRev = sum [ if ty `like` "PROMO%"
                     then revenue ep discount
                     else 0
                   | (view -> (ty, ep, discount)) <- itemPrices startDate
                   ]

    totalRev = sum $ map (\(view -> (_, ep, d)) -> revenue ep d)
                   $ itemPrices startDate

-------------------------------------------------------------------------------
-- Variation which uses a subquery to reduce the number of tuples that go
-- into the aggregate. This formulation might be beneficial if the p_type 
-- predicate can be pushed to an index.

q14a :: Day -> Q Decimal
q14a startDate = 100.0 * promoRev / totalRev
  where
    promoRev = sum [ revenue ep dis
                   | (view -> (ty, ep, dis)) <- itemPrices startDate
                   , ty `like` "PROMO%"
                   ]

    totalRev = sum $ map (\(view -> (_, ep, d)) -> revenue ep d)
                   $ itemPrices startDate
