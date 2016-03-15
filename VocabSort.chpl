module VocabSort {

  private inline proc chpl_sort_cmp(a, b, param reverse=false, param eq=false) {
    if eq {
      if reverse then return a >= b;
      else return a <= b;
    } else {
      if reverse then return a > b;
      else return a < b;
    }
  }

  proc XInsertionSort(Data: [?Dom] VocabEntry, doublecheck=false, param reverse=false) where Dom.rank == 1 {
    const lo = Dom.low;
    for i in Dom {
      const ithVal = Data(i);
      var inserted = false;
      for j in lo..i-1 by -1 {
        if (chpl_sort_cmp(ithVal.cn, Data(j).cn, reverse)) {
          Data(j+1) = Data(j);
        } else {
          Data(j+1) = ithVal;
          inserted = true;
          break;
        }
      }
      if (!inserted) {
        Data(lo) = ithVal;
      }
    }

    /*if (doublecheck) then VerifySort(Data, "InsertionSort", reverse);*/
  }

  proc QuickSort(Data: [?Dom] VocabEntry, minlen=7, doublecheck=false, param reverse=false) where Dom.rank == 1 {
    // grab obvious indices
    const lo = Dom.low,
          hi = Dom.high,
          mid = lo + (hi-lo+1)/2;

    // base case -- use insertion sort
    if (hi - lo < minlen) {
      XInsertionSort(Data, reverse=reverse);
      return;
    }

    // find pivot using median-of-3 method
    if (chpl_sort_cmp(Data(mid).cn, Data(lo).cn, reverse)) then Data(mid) <=> Data(lo);
    if (chpl_sort_cmp(Data(hi).cn, Data(lo).cn, reverse)) then Data(hi) <=> Data(lo);
    if (chpl_sort_cmp(Data(hi).cn, Data(mid).cn, reverse)) then Data(hi) <=> Data(mid);
    const pivotVal = Data(mid);
    Data(mid) = Data(hi-1);
    Data(hi-1) = pivotVal;
    // end median-of-3 partitioning

    var loptr = lo,
        hiptr = hi-1;
    while (loptr < hiptr) {
      do { loptr += 1; } while (chpl_sort_cmp(Data(loptr).cn, pivotVal.cn, reverse));
      do { hiptr -= 1; } while (chpl_sort_cmp(pivotVal.cn, Data(hiptr).cn, reverse));
      if (loptr < hiptr) {
        Data(loptr) <=> Data(hiptr);
      }
    }

    Data(hi-1) = Data(loptr);
    Data(loptr) = pivotVal;

    //  cobegin {
      QuickSort(Data[..loptr-1], reverse=reverse);  // could use unbounded ranges here
      QuickSort(Data[loptr+1..], reverse=reverse);
      //  }

    /*if (doublecheck) then VerifySort(Data, "QuickSort", reverse);*/
  }  
}
