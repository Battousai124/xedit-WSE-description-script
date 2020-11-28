unit EffsTableTools;

// This unit only contains static functions to handle an internal pseudo table data type, no variables
// what is called "table" here is intended to be used as a List<Class> equivalent
// (it requires EffsDebugLog being loaded)

implementation

uses 'Effs_Lib\EffsStringTools';

//=========================================================================
//  MOST IMPORTANT METHOD
//  needs to be called instead of just .Free on the TStringlist to free the memory
//  also destroys the inner TStringLists holding the actual data
//=========================================================================
procedure DestroyTable(table : TStringList;);
var 
	i, j : Integer;
begin
	//LogFunctionStart('DestroyTable');
	
	//destroying all TStringLists that may exist in the main table
	i := 0;
	while i < table.Count do begin 
		if not (table.Objects[i] = nil) then begin
		
			j := 0;
			while j < TStringList(table.Objects[i]).Count do begin 
				if not (TStringList(table.Objects[i]).Objects[j] = nil) then begin
					TStringList(TStringList(table.Objects[i]).Objects[j]).Free;
					TStringList(table.Objects[i]).Objects[j] := nil;
				end;
				inc(j);
			end;
		
			TStringList(table.Objects[i]).Free;
			table.Objects[i] := nil;
		end;
		inc(i);
	end;
	
	table.Free;
	table := nil;
	
	//LogFunctionEnd;
end;

//=========================================================================
//  convert a string list into an internal table structure
//=========================================================================
procedure NewEmptyTable(table : TStringList; const hasHeaders :Boolean;);
begin
	//LogFunctionStart('CreateNewEmptyTable');
	
	table.Clear;
	table.Add('data=(sublist)'); //always the 1st row
	table.Objects[0] := TStringList.Create; 
	//data inside is stored as columns - with info entries at index 0
	//	[0] is an info entry about the table - contains the row and col count for fast reading access
	//	[0][1] is an info entry about the first row ???
	//	[1] is the header of the first column
	//	[1][0] is an info entry about the first column ???
	//	[1][1] is the cell in the first column in the first row
	//	[1][2] is the cell in the first column in the second row, ...and so on
	TStringList(table.Objects[0]).Add('0=0'); //unfilteredRowCount=unfilteredColCount
	
	table.Add('rowIndices=(sublist)'); //always the 2nd row
	table.Objects[1] := TStringList.Create;
	//	[0] is an info entry about row-indices (contains number of rows visible after filters)
	//	[1] contains the unfiltered index that the filtered index 1 points to after filters (as string)
	//	[2] contains the unfiltered index that the filtered index 2 points to after filters (as string)
	// if there is no filtering, the list contains only the first entry (and none greater than 0)
	TStringList(table.Objects[1]).Add('c=0');
	
	table.Add('colIndices=(sublist)'); //always the 3rd row
	table.Objects[2] := TStringList.Create;
	//	[0] is an info entry about col-indices (contains number of columns visible after considering hidden columns)
	//	[1] contains the unfiltered index that the filtered index 1 points to after considering hidden columns (as string)
	//	[2] contains the unfiltered index that the filtered index 2 points to after considering hidden columns (as string)
	// if there is no hidden column, the list contains only the first entry (and none greater than 0)
	TStringList(table.Objects[2]).Add('c=0');
	
	//always the 4th row
	if hasHeaders then begin
		table.Add('hasHeaders=true');
	end else begin 
		table.Add('hasHeaders=false');
	end;
	
	//table.Add('c_fil=0'); //count of active filters
	
	table.Add('rowFilters=(sublist)'); //always the 5th row
	table.Objects[4] := TStringList.Create;
	//	[0] is the name of the filter
	//	[0][0] contains the first (unfiltered) row index that should be filtered out
	//	[0][1] contains the second (unfiltered) row index that should be filtered out
	
	table.Add('hiddenColumns=(sublist)'); //always the 6th row
	table.Objects[5] := TStringList.Create;
	//	[0] contains the first (unfiltered) col index that should be hidden
	//	[1] contains the second (unfiltered) col index that should be hidden
	
		
	//LogFunctionEnd;
end;


//TODOs: 

//TableColumnIsHidden
//HideTableColumn
//UnhideTableColumn
//UnhideAllTableColumns
//GetUnfilteredTableColCount

//CopyTable   WithoutFilteredOutData ...copyFilteredOutRows, copyHiddenColumns
//RemoveFilteredOutDataFromTable

//FormatTableColumn //also changes datatype to String

//ChangeColumnOrder //list of names

//AddTableRow
//RemoveTableRow //slow for large tables

//=========================================================================
//  add a column to the table and returns the unique name of the column
//	header: the column header of the column
//		if the table has no headers, it will be ignored and returned as it was provided
//		if it is empty it will be automatically set to the next unique header starting with "Column1" then "Column2" and so on 
//		if it is not unique then a number will be added as a postfix, starting with "2"
//	dataTypeStr: string repesentation of the datatype the new columns should have
//		if left empty will default to "String"
//		will throw an error if called with anything else than "", "String", "Float", "Boolean" or "Integer"
//=========================================================================
function AddTableColumn(table : TStringList; const suggestedHeader : String; const dataTypeStr : String;) : String; 
var 
	datatype, counter, colIndex, colCount, tmpInt : Integer;
	header, newHeaderWithoutCounter : String;
	headers : TStringList;
begin
	LogFunctionStart('AddTableColumn');

	header := suggestedHeader;
	colCount := GetTableColCount(table);
	colIndex := colCount + 1;
	
	//get and set datatype
	if SameText(dataTypeStr, '') then begin
		datatype := 1;
	end else begin 
		datatype := StringDataTypeToIntDataType(dataTypeStr);
	end;
	table.Add(Format('dt%d=%d',[colIndex, datatype]));

	//set header if the table has headers
	if TableHasHeaders(table) then begin 
		headers := TStringList.Create;
		headers.Sorted := true; //so that .Find() works
		
		try
			GetTableHeadersAsList(table, headers);
			
			//get next free unique header
			if SameText(header, '') then begin 
				newHeaderWithoutCounter := 'Column';
				header := 'Column1';
			end else begin 
				newHeaderWithoutCounter := header;
			end;
			
			counter := 1;
			while headers.Find(header, tmpInt) do begin
				inc(counter);
				header := Format('%s%d',[newHeaderWithoutCounter, counter]);
			end;

			// DebugLog('header: ' + header);
			
			table.Add(Format('h%d=%s',[colIndex, header]));
		
		finally
			headers.Free;
			headers := nil;
		end;
	end;


	//count up the number of columns
	TStringList(table.Objects[0]).Strings[0] := Format('%d=%d', [GetUnfilteredTableRowCount(table, false), GetTableColCount(table) + 1]);
	TStringList(table.Objects[2]).Strings[0] := IntToStr(colCount + 1);
	
	
	//return the header for the case that it was not unique and was changed in this function
	Result := header;
	
	LogFunctionEnd;
end;

//=========================================================================
//  sort the rows of a table by the contents of a column
//	sorting is done according to the data type of the column
//	all rows will be sorted, even if they are filtered out at the moment
//		however, the filters persist. they will not be lost by sorting.
//		But if you remove a filter afterwards, the row will be properly sorted.
//=========================================================================
procedure SortTableByColumn(table : TStringList; const colIndexOrHeader : Variant;);
var
	i, tmpInt, colIndex, unfilteredRowCount, datatype, filteredRowIndex : Integer;
	curVal : String;
	curFloatValue : Double;
	sortList, orderedIndexList : TStringList;
begin
	LogFunctionStart('SortTableByColumn');
	
	colIndex := TableColIndexByVariant(table, colIndexOrHeader);
	unfilteredRowCount := GetUnfilteredTableRowCount(table, false);
	datatype := GetTableColumnDataType(table, colIndex);
	
	sortList := TStringList.Create;
	orderedIndexList := TStringList.Create;
	
	try
		//gather string representations of the cells in this column in a row to be sorted
		i := 1;
		while i <= unfilteredRowCount do begin
			filteredRowIndex := TranslateUnfilteredToFilteredTableIndex(table, i, 1);
			curVal := table.Values[Format('%d|%d', [filteredRowIndex, colIndex])];
			
			case datatype of 
				1: sortList.AddObject(curVal, TObject(i));
				8: begin 
						if not SameText(curVal, 'true') then 
							curVal := 'false';
						sortList.AddObject(curVal, TObject(i));
					end;
				3,9: begin
						if SameText(curVal, '') then begin
							curFloatValue := 0.0;
						end else begin
							curFloatValue := StrToFloat(curVal);
						end;
						if curFloatValue < 0 then begin
							curFloatValue := 9999999999 + curFloatValue;
							curVal := FormatFloat('a0000000000.##########;a-0000000000.##########;""', curFloatValue);
						end else begin
							curVal := FormatFloat('c0000000000.##########;;"b"', curFloatValue);
						end;
						sortList.AddObject(curVal, TObject(i));
					end;
			end;
			inc(i);
		end;
		
		//sort it 
		sortList.Sort;
		
		//compile sorted indices into a list
		i := 0;
		while i < sortList.Count do begin
			tmpInt := sortList.Objects[i];
			orderedIndexList.Add(IntToStr(tmpInt));
			inc(i);
		end;
		
		ChangeTableIndexOrder(table, 1, orderedIndexList, false);
		
	finally
		sortList.Free;
		sortList := nil;
		orderedIndexList.Free;
		orderedIndexList := nil;
	end;
	
	LogFunctionEnd;
end;


//=========================================================================
//  change the order of rows or columns in the table according to a list provided
//	indexType: 1=Rows, 2=Columns
//	orderedIndexList: List of indices - should be unique integer values 
//		the new order will start with the indices in the list. 
//			If there are indices not present in the list, they will be appended in their current order after the ones in the list.
//		if it contains an index several times, only the first instance will be considered
//		empty entries will be ignored
//		non-existing indices will be ignored
//	indicesAreFilteredIndices: true means that the indices in the list are the ones that are accessible when reading the table
//		false means that it contains hidden indices (in case of filters or hidden columns)
//=========================================================================
procedure ChangeTableIndexOrder(table : TStringList; const indexType : Integer; orderedIndexList : TStringList; const indicesAreFilteredIndices : Boolean;);
const
	columnDelimiter = ',';
	emptyString = '';
var 
	i, j, tmpInt, unfilteredCount, unfilteredRowCount, filteredCount, filteredIndex, index, rowIndex, colIndex, rowCount, colCount, filterCount : Integer;
	tmpStr, currentFilter, indexStr : String;
	found : Boolean;
	copiedValuesList : TStringList;
begin
	LogFunctionStart('ChangeTableIndexOrder');
	
	//make list distinct
	DistinctList(orderedIndexList, true);
	
	if orderedIndexList.Count > 0 then begin 
		colCount := GetTableColCount(table);
		unfilteredRowCount := GetUnfilteredTableRowCount(table, false);
		
		if indexType = 1 then begin 
			unfilteredCount := unfilteredRowCount;
			filteredCount := GetTableRowCount(table, false);
		end else begin
			unfilteredCount := colCount;
			filteredCount := GetTableColCount(table);
		end;
	
		if indicesAreFilteredIndices then begin 
			i := orderedIndexList.Count - 1;
			while i >= 0 do begin
				filteredIndex := StrToInt(orderedIndexList[i]);
				if (filteredIndex < 1) or (filteredIndex > filteredCount) then begin
					//throw out non existing indices
					orderedIndexList.Delete(i);
				end else begin
					//translate indices to unfilteredIndices if they are filtered
					orderedIndexList[i] := IntToStr(TranslateFilteredToUnfilteredTableIndex(table, filteredIndex, indexType));
				end;
				i := i - 1;
			end;
		end else begin 
			i := orderedIndexList.Count - 1;
			while i >= 0 do begin
				index := StrToInt(orderedIndexList[i]);
				if (index < 1) or (index > unfilteredCount) then begin
					//throw out non existing indices
					orderedIndexList.Delete[i];
				end;
				i := i - 1;
			end;
		end;
		
		//add missing indices
		if not (orderedIndexList.Count = unfilteredCount) then begin 
			
			//probably not necessary, as the unfiltered entries are already sorted
			// //fist add visible indices
			// i := 1;
			// while i <= filteredCount do begin
				// tmpStr := IntToStr(TranslateFilteredToUnfilteredTableIndex(table, i, indexType));
				// found := false;
				// j := 0;
				// while j < orderedIndexList.Count do begin
					// if SameText(tmpStr, orderedIndexList[j]) then begin
						// found := true;
						// break;
					// end;
					// inc(j);
				// end;
				
				// if not found then 
					// orderedIndexList.Add(tmpStr);
				
				// inc(i);
			// end;
			
			// //now add some filtered out indices if there are still some missing
			// if not (orderedIndexList.Count = unfilteredCount) then begin 
				i := 1;
				while i <= unfilteredCount do begin
					tmpStr := IntToStr(i);
					found := false;
					j := 0;
					while j < orderedIndexList.Count do begin
						if SameText(tmpStr, orderedIndexList[j]) then begin
							found := true;
							break;
						end;
						inc(j);
					end;
					
					if not found then 
						orderedIndexList.Add(tmpStr);
					
					inc(i);
				end;
			// end;
		end;
		//->now we have a complete ordered list of unfiltered indices

		copiedValuesList := TStringList.Create;
		try
			//copy data into an unfiltered list
			i := 1;
			while i <= unfilteredRowCount do begin
				rowIndex := TranslateUnfilteredToFilteredTableIndex(table, i, 1);
				
				j := 1;
				while j <= colCount do begin
					colIndex := j; //TODO: consider hidden columns
					copiedValuesList.Values[Format('%d|%d', [i, j])] := table.Values[Format('%d|%d', [rowIndex, colIndex])];
					inc(j);
				end;
				
				inc(i);
			end;
			
			//re-order the indices in the table
			if indexType = 1 then begin 
				i := 1;
				while i <= unfilteredRowCount do begin
					indexStr := orderedIndexList[i - 1];
					
					j := 1;
					while j <= colCount do begin
						table.Values[Format('%d|%d', [i, j])] := copiedValuesList.Values[Format('%s|%d', [indexStr, j])];
						inc(j);
					end;
					
					//table.Values[Format('r%d|filteredBy', [i])] := copiedValuesList.Values[Format('r%s|filteredBy', [indexStr])];
					inc(i);
				end;
			end;			
			//TODO: also re-order columns
			
			
			//re-build the filters (replace the filtered out indices with the new sorting)
			filterCount := TStringList(table.Objects[indexType + 3]).Count; //either index 4 for rowIndices or index 5 for columnIndices
			i := 0;
			while i < filterCount do begin
				tmpInt := TStringList(TStringList(table.Objects[indexType + 3]).Objects[i]).Count;
				j := 0;
				while j < tmpInt do begin
					tmpStr := TStringList(TStringList(table.Objects[indexType + 3]).Objects[i]).Strings[j];
					TStringList(TStringList(table.Objects[indexType + 3]).Objects[i]).Strings[j] := IntToStr(orderedIndexList.IndexOf(tmpStr) + 1);
				end;
				inc(i);
			end;
			
			RefreshTableIndexes(table, indexType);
			
		finally 
			copiedValuesList.Free;
			copiedValuesList := nil;
		end;
		
	end;
	LogFunctionEnd;
end;

//=========================================================================
//  removes a row filter from a column
//=========================================================================
procedure RemoveAllFiltersFromTable (const table : TStringList);
const
	columnDelimiter = ',';
	emptyString = '';
var
	i, j : Integer;
begin
	LogFunctionStart('RemoveAllFiltersFromTable');
	
	i := 4;
	while i <= 5 do begin 
		j := 0;
		while j < TStringList(table.Objects[i]).Count do begin 
			TStringList(TStringList(table.Objects[i]).Objects[j]).Free;
			TStringList(table.Objects[i]).Objects[j] := nil;
			inc(j);
		end;
		TStringList(table.Objects[i]).Clear;
		inc(i);
	end;
	
	RefreshTableIndexes(table, 1);
	
	LogFunctionEnd;
end;


//=========================================================================
//  removes a row filter from a column
//=========================================================================
procedure RemoveFilterFromTableColumn (const table : TStringList; const colIndexOrHeader : Variant;);
var
	colIndex : Integer;
begin
	LogFunctionStart('RemoveFilterFromTableColumn');

	colIndex := TableColIndexByVariant(table, colIndexOrHeader);
	RemoveSpecificFilterFromTable(table, Format('rFil-c%d', [colIndex]));
	
	LogFunctionEnd;
end;

//=========================================================================
//  removes one specific filter from a table 
//=========================================================================
procedure RemoveSpecificFilterFromTable(const table : TStringList; const filterId : String;);
var
	filterIndex : Integer;
begin
	LogFunctionStart('RemoveSpecificFilterFromTable');
	
	filterIndex := TStringList(table.Objects[4]).IndexOf(filterId);
	
	if filterIndex > -1 then begin 
		
		//delete the filter
		TStringList(TStringList(table.Objects[4]).Objects[filterIndex]).Free;
		TStringList(table.Objects[4]).Delete(filterIndex);
		
		//refresh the filtered index of all rows
		RefreshTableIndexes(table, 1);
	end;
	
	LogFunctionEnd;
end;

//=========================================================================
//  refreshes the indexes in the table after adding or removing a filter
//	indexType: 1=rows, 2=columns
//=========================================================================
procedure RefreshTableIndexes(const table : TStringList; const indexType : Integer;);
var
	i, j, unfilteredRowCount, colCount, filteredRowIndex, oldfilteredRowIndex, tmpInt, filterCount : Integer;
	curVal, currentFilter, tmpStr : String;
	tmpList, oldIndices, filteredOutIndicesList : TStringList;
begin
	LogFunctionStart('RefreshTableIndexes');
	
	tmpList := TStringList.Create;
	oldIndices := TStringList.Create;
	filteredOutIndicesList := TStringList.Create;
	filteredOutIndicesList.Sorted := true;
	filteredOutIndicesList.Duplicates := dupIgnore;
	
	try
		//copy the unfiltered table data to a temporary list
		CopyList(table,tmpList);
		
		// DebugLog(Format('raw contents of table: %s', [table.Text]));
		// DebugLog(Format('raw contents of tmpList: %s', [tmpList.Text]));		
		
		unfilteredRowCount := GetUnfilteredTableRowCount(table, false);
		colCount := GetTableColCount(table);
		filterCount := TStringList(table.Objects[indexType + 3]).Count; //either index 4 for rowIndices or index 5 for columnIndices
		
		//also copy the old translation of the old indices before deleting them
		CopyList(TStringList(table.Objects[indexType]), oldIndices);
		
		// DebugLog(Format('raw contents of table.Objects[indexType]: %s', [TStringList(table.Objects[indexType]).Text]));		
		// DebugLog(Format('raw contents of oldIndices: %s', [oldIndices.Text]));		
		
		//clear translation between filtered and unfiltered indices (and the count of visible rows/columns)
		TStringList(table.Objects[indexType]).Clear; 
		
		if filterCount = 0 then begin 
			if indexType = 1 then begin 
				TStringList(table.Objects[indexType]).Add(Format('c=%d', [unfilteredRowCount]));
			end else begin 
				TStringList(table.Objects[indexType]).Add(Format('c=%d', [colCount]));
			end;
		end else begin
			//write a dummy value as count, so that it stays at index 0
			TStringList(table.Objects[indexType]).Add('c=0');
		
			//write a translation for every index that is visible
			if indexType = 1 then begin 
				
				//build a unique list of filtered out rows
				i := 0;
				while i < filterCount do begin
					tmpInt := TStringList(TStringList(table.Objects[indexType + 3]).Objects[i]).Count;
					j := 0;
					while j < tmpInt do begin
						tmpStr := TStringList(TStringList(table.Objects[indexType + 3]).Objects[i]).Strings[j];
						filteredOutIndicesList.Add(tmpStr);
						inc(j);
					end;
					inc(i);
				end;
				
				// DebugLog(Format('raw contents of table.Objects[indexType]: %s', [TStringList(table.Objects[indexType]).Text]));		
				// DebugLog(Format('raw contents of oldIndices: %s', [oldIndices.Text]));		
			
				i := 1;
				filteredRowIndex := 0;
				while i <= unfilteredRowCount do begin
					// currentFilter := table.Values[Format('r%d|filteredBy', [i])];
					if oldIndices.Count > 1 then begin 
						oldfilteredRowIndex := oldIndices.IndexOf(IntToStr(i)) ;
						if oldfilteredRowIndex < 0 then oldfilteredRowIndex := (i * -1);
					end else begin
						oldfilteredRowIndex := i;
					end;
					
					j := 1;
					if filteredOutIndicesList.IndexOf(IntToStr(i)) < 0 then begin 
						inc(filteredRowIndex);
						while j <= colCount do begin
							curVal := tmpList.Values[Format('%d|%d', [oldfilteredRowIndex, j])];
							if SameText(curVal, '') then begin 
								// DebugLog(Format('curVal is empty - filteredRowIndex: %d, oldfilteredRowIndex: %d, j: %d, curVal: %s', [filteredRowIndex, oldfilteredRowIndex, j, curVal]));
								tmpStr := Format('%d|%d', [filteredRowIndex, j]);
								tmpInt := table.IndexOfName(tmpStr);
								if tmpInt > -1 then 
									table[tmpInt] := tmpStr + '='; //overwriting it should be faster than setting it to '' which would delete it and therefore re-order the table
							end else begin
								// DebugLog(Format('curVal is not empty - filteredRowIndex: %d, oldfilteredRowIndex: %d, j: %d, curVal: %s', [filteredRowIndex, oldfilteredRowIndex, j, curVal]));
								table.Values[Format('%d|%d', [filteredRowIndex, j])] := curVal;
							end;
							inc(j);
						end;
						TStringList(table.Objects[indexType]).Add(IntToStr(i));
					end else begin
						while j <= colCount do begin
							curVal := tmpList.Values[Format('%d|%d', [oldfilteredRowIndex, j])];
							if SameText(curVal, '') then begin 
								tmpStr := Format('%d|%d', [i * -1, j]);
								tmpInt := table.IndexOfName(tmpStr);
								if tmpInt > -1 then 
									table[tmpInt] := tmpStr + '=';
							end else begin 
								table.Values[Format('%d|%d', [i * -1, j])] := curVal;
							end;
							inc(j);
						end;
					end;
					inc(i);
				end;
				
				//set the new filtered row count
				//(the highest index of a row that is still visible at the moment is the new filtered row count)
				TStringList(table.Objects[indexType]).Strings[0] := Format('c=%d', [filteredRowIndex]);
				// DebugLog(Format('new indexTranslation: %s', [TStringList(table.Objects[indexType]).Text]));
			end;
			//end else begin 
				//TODO: cover hiden columns
		end;
		
	finally
		tmpList.Free;
		tmpList := nil;
		oldIndices.Free;
		oldIndices := nil;
		filteredOutIndicesList.Free;
		filteredOutIndicesList := nil;
	end;
	
	LogFunctionEnd;
end;

//=========================================================================
//  returns true if a table column has an active filter
//=========================================================================
function TableColumnHasActiveFilter(const table : TStringList; const colIndexOrHeader : Variant;) : Boolean;
var
	colIndex : Integer;
begin
	//LogFunctionStart('TableColumnHasActiveFilter');

	colIndex := TableColIndexByVariant(table, colIndexOrHeader);
	Result := not SameText('', table.Values[Format('rFil-c%d', [colIndex])]);

	//LogFunctionEnd;
end;

//=========================================================================
//	set a manual filter to the table
//	returns the number of rows/columns filtered out that were not filtered out already
//	indexType: 1=Row, 2=Column
//	filterId: unique string identifying the filter
//		if not set: a unique index name will be automatically created for internal storage of the filter
//		if set: may not be in use at the moment for another filter
//	filteredOutIndicesList: TStringList containing a unique set of integer indices to filter out
//	indicesAreFilteredIndices: (use true as default if you call it from your code)
//		if true: interprets the indices in the list as filtered indices (filtered indices are the ones visible at the moment)
//		if false: interprets the indices in the list as unfiltered indices 
//=========================================================================
function SetManualFilterToTable(const table : TStringList; const indexType : Integer; filterId : String; filteredOutIndicesList : TStringList; const indicesAreFilteredIndices : Boolean;) : Integer;
const
	newFilterIdWithoutCounter = 'mFil-';
var
	i, j, counter, index, newlyFilteredOutRowCount, filterIndex, filterCount : Integer;
	tmpStr, filterIdPostfix, currentFilter : String;
begin
	LogFunctionStart('SetManualFilterToTable');
	
	newlyFilteredOutRowCount := 0;

	if filteredOutIndicesList.Count > 0 then begin 
		//get a new unique filterId if it was not provided
		if SameText(filterId, '') then begin 
			counter := 1;
			filterId := Format('%s%d%s',[newFilterIdWithoutCounter, counter, filterIdPostfix]);
			
			filterIndex := TStringList(table.Objects[4]).IndexOf(filterId);
			
			while filterIndex > -1 do begin
				inc(counter);
				filterId := Format('%s%d%s',[newFilterIdWithoutCounter, counter, filterIdPostfix]);
				filterIndex := TStringList(table.Objects[4]).IndexOf(filterId);
			end;
		end;
		
		//check if the filterId is unique
		filterIndex := TStringList(table.Objects[4]).IndexOf(filterId);
		if filterIndex > -1 then
			raise Exception.Create(Format('Could not set new filter. FilterId is not unique. FilterId: %s', [filterId]));
	
		//translate the indices from filtered to unfiltered if necessary
		if indicesAreFilteredIndices then begin 
			//DebugLog(Format('indicesAreFilteredIndices - filteredOutIndicesList: %s', [filteredOutIndicesList.Text]));
			i := 0;
			while i < filteredOutIndicesList.Count do begin
				index := StrToInt(filteredOutIndicesList[i]);
				filteredOutIndicesList[i] := IntToStr(TranslateFilteredToUnfilteredTableIndex(table, index, indexType));
				inc(i);
			end;
			//DebugLog(Format('filteredOutIndicesList changed: %s', [filteredOutIndicesList.Text]));
		end;
	
		//remember that this filter wants to filter out these indices
		filterCount := TStringList(table.Objects[4]).Count;
		TStringList(table.Objects[4]).Add(filterId);
		TStringList(table.Objects[4]).Objects[filterCount] := TStringList.Create;
		CopyList(filteredOutIndicesList, TStringList(TStringList(table.Objects[4]).Objects[filterCount]));
		
		//refresh the filtered index of all rows
		RefreshTableIndexes(table, 1);
		//TODO: also check filters on columns
	end;
	
	Result := newlyFilteredOutRowCount;
	
	LogFunctionEnd;
end;

//=========================================================================
//	internal function to translate a filtered row or column index to the unfiltered index
//=========================================================================
function TranslateFilteredToUnfilteredTableIndex(const table : TStringList; const filteredIndex, indexType : Integer;) : Integer;
var
	tmpStr : String;
begin
	//LogFunctionStart('TranslateFilteredToUnfilteredTableIndex');
	
	if TStringList(table.Objects[indexType]).Count > 1 then begin 
		if filteredIndex < 0 then begin
			Result := filteredIndex * -1;
		end else begin 
			Result := StrToInt(TStringList(table.Objects[indexType]).Strings(filteredIndex));
		end;
	end else begin
		Result := filteredIndex;
	end;

	//LogFunctionEnd;
end;

//=========================================================================
//	internal function to translate an unfiltered row or column index to the filtered index
//	indexType: 1=rows, 2=columns
//=========================================================================
function TranslateUnfilteredToFilteredTableIndex(const table : TStringList; const unfilteredIndex, indexType : Integer;) : Integer;
var
	tmpStr : String;
begin
	//LogFunctionStart('TranslateUnfilteredToFilteredTableIndex');
	
	if TStringList(table.Objects[indexType]).Count > 1 then begin 
		Result := TStringList(table.Objects[indexType]).IndexOf(IntToStr(unfilteredIndex)) ;
		if Result < 0 then Result := (unfilteredIndex * -1);
	end else begin
		Result := unfilteredIndex;
	end;

	//LogFunctionEnd;
end;

//=========================================================================
//	set a filter to a column that can filter out rows of the table
//  returns the number of rows that have been filtered out by this filter
//	(this number only counts rows that are not already filtered out by another filter
//  	and it does not consider the effect that another filter maybe present on this column at the moment may have filtered out other rows or more rows
//		-> the number represents the amount of rows filtered out in comparison to if this column would not have a filter)
//	A filter does not delete the data filtered out, but just hides it. 
//	If you apply a filter to a column that already carries a filter at the moment, 
//		the existing filter will be removed and then the new filter will be set
//	keepEmptyCells only works for String-Columns. if it is true, the filter will not be applied for empty cells 
//		-> i.e. rows with empty cells will not be filtered out.
//	like in Excel: a filter is not automatically re-applied when new data is added. it needs to be set again to cover new rows.
//	if the new filter would not filter any row, the column will not have a filter after the operation 
//		-> a filter that filters zero rows is not necessary to be stored in any way
//	the filter to apply will always consider all rows, not only the ones that are visible at the moment 
//		-> if you remove another filter afterwards, and both filter out a row, the row will stay filtered out
//		-> also means: if you filtered out a large number of rows with another filter, applying the next filter will not be faster.
//			if you want it to be faster, use RemoveFilteredOutDataFromTable before applying the next filter
//=========================================================================
function SetFilterToTableColumn(const table : TStringList; const colIndexOrHeader : Variant; const operator : String; const compareValue : Variant; const keepEmptyCells : Boolean; ) : Integer;
var
	i, unfilteredRowCount, filteredRowIndex, newlyFilteredOutRowCount, colIndex, datatype : Integer;
	stringValue, stringCompareValue, filterId: String;
	floatValue, floatCompareValue : Double; 
	boolValue, boolCompareValue : Boolean;
	filteredOutRowsList : TStringList;
begin
	LogFunctionStart('SetFilterToTableColumn');

	//check if the operator used is valid
	if not (
		SameText(operator, '=') or SameText(operator, '<>') or SameText(operator, '<') or SameText(operator, '<=') or SameText(operator, '>') or SameText(operator, '>=')
		or SameText(operator, 'beginsWith') or SameText(operator, 'endsWith') or SameText(operator, 'contains') or SameText(operator, 'doesNotContain')
		) then 
		raise Exception.Create(Format('The operator provided as filter is not valid. Operator: %s (Supported operators: "=", "<>", "<", "<=", ">", ">=", "beginsWith", "endsWith", "contains", "doesNotContain")', [operator]));

	colIndex := TableColIndexByVariant(table, colIndexOrHeader);
	datatype := GetTableColumnDataType(table, colIndex);
	
	//prepare the comparison value (always have a string compareValue ready for certain operators)
	case datatype of 
		1: stringCompareValue := compareValue;
		3,9: begin
				floatCompareValue := compareValue;
				// stringCompareValue := FormatFloat('0.##########;-0.##########;"0"', floatCompareValue);
				if SameText(operator, 'beginsWith') or SameText(operator, 'endsWith') 
					or SameText(operator, 'contains') or SameText(operator, 'doesNotContain') then begin 
						raise Exception.Create(Format('The operator provided as filter is not valid for a numeric column. Operator: %s (Supported operators for numeric columns: "=", "<>", "<", "<=", ">", ">=")', [operator]));
				end;
			end;
		8: begin
				boolCompareValue := compareValue;
				// if boolCompareValue then begin
					// stringCompareValue := 'true';
				// end else begin
					// stringCompareValue := 'false';
				// end;
				
				if SameText(operator, '<') or SameText(operator, '<=') or SameText(operator, '>') or SameText(operator, '>=') 
					or SameText(operator, 'beginsWith') or SameText(operator, 'endsWith') 
					or SameText(operator, 'contains') or SameText(operator, 'doesNotContain') then begin 
						raise Exception.Create(Format('The operator provided as filter is not valid for a Boolean column. Operator: %s (Supported operators for Boolean columns: "=", "<>")', [operator]));
				end;
			end;
	end;
	
	filterId := Format('rFil-c%d', [colIndex]);
	
	//remove filter from column if it has one at the moment
	RemoveSpecificFilterFromTable(table, filterId);
	
	//after removing the filter, get the rows to check
	//always filter all rows, even if they may be filtered out by other filters already
	unfilteredRowCount := GetUnfilteredTableRowCount(table, false);
	newlyFilteredOutRowCount := 0;
	
	filteredOutRowsList := TStringList.Create;
	try
		
		i := 1;
		while i <= unfilteredRowCount do begin
			filteredRowIndex := TranslateUnfilteredToFilteredTableIndex(table, i, 1);
			
			//get cell value to compare
			stringValue := table.Values[Format('%d|%d', [filteredRowIndex, colIndex])];
			
			if datatype = 1 then begin 
				if not (SameText(stringValue, '') and keepEmptyCells) then begin
					//do the compare operation and remember that a row is filtered out if the condition is not met
					if SameText(operator, '=') then begin
						if not SameText(stringValue, stringCompareValue) then
							filteredOutRowsList.Add(IntToStr(i));
					end;
					if SameText(operator, '<>') then begin
						if SameText(stringValue, stringCompareValue) then
							filteredOutRowsList.Add(IntToStr(i));
					end;
					if SameText(operator, '<') then begin
						if not (stringValue < stringCompareValue) then
							filteredOutRowsList.Add(IntToStr(i));
					end;
					if SameText(operator, '<=') then begin
						if not (stringValue <= stringCompareValue) then
							filteredOutRowsList.Add(IntToStr(i));
					end;
					if SameText(operator, '>') then begin
						if not (stringValue > stringCompareValue) then
							filteredOutRowsList.Add(IntToStr(i));
					end;
					if SameText(operator, '>=') then begin
						if not (stringValue >= stringCompareValue) then
							filteredOutRowsList.Add(IntToStr(i));
					end;
					if SameText(operator, 'beginsWith') then begin 
						if not SameText(Copy(stringValue, 1, Length(stringCompareValue)), stringCompareValue) then
							filteredOutRowsList.Add(IntToStr(i));
					end;
					if SameText(operator, 'endsWith') then begin
						if Length(stringCompareValue) > Length(stringValue) then begin
							filteredOutRowsList.Add(IntToStr(i));
						end else begin
							if not SameText(Copy(stringValue, Length(stringValue)-Length(stringCompareValue) + 1, Length(stringCompareValue)), stringCompareValue) then
								filteredOutRowsList.Add(IntToStr(i));
						end;
					end;
					if SameText(operator, 'contains') then begin 
						if Pos(stringCompareValue, stringValue) < 0 then
							filteredOutRowsList.Add(IntToStr(i));
					end;
					if SameText(operator, 'doesNotContain') then begin 
						if Pos(stringCompareValue, stringValue) > -1 then
							filteredOutRowsList.Add(IntToStr(i));
					end;
				end;
			end;
			
			if datatype = 8 then begin 
				//get right datatype to compare
				boolValue := SameText(stringValue, 'true');
				
				//do the compare operation and remember that a row is filtered out if the condition is not met
				if SameText(operator, '=') then begin
					if not (boolValue = boolCompareValue) then
						filteredOutRowsList.Add(IntToStr(i));
				end;
				if SameText(operator, '<>') then begin
					if (boolValue = boolCompareValue) then
						filteredOutRowsList.Add(IntToStr(i));
				end;
			end;
			
			if (datatype = 3) or (datatype = 9) then begin
				//get right datatype to compare (compare only floats, also works for integers)
				if SameText(stringValue, '') then begin
					floatValue := 0.0;
				end else begin
					floatValue := StrToFloat(stringValue);
				end;
				
				//do the compare operation and remember that a row is filtered out if the condition is not met
				if SameText(operator, '=') then begin
					if not (floatValue = floatCompareValue) then
						filteredOutRowsList.Add(IntToStr(i));
				end;
				if SameText(operator, '<>') then begin
					if floatValue = floatCompareValue then
						filteredOutRowsList.Add(IntToStr(i));
				end;
				if SameText(operator, '<') then begin
					if not (floatValue < floatCompareValue) then
						filteredOutRowsList.Add(IntToStr(i));
				end;
				if SameText(operator, '<=') then begin
					if not (floatValue <= floatCompareValue) then
						filteredOutRowsList.Add(IntToStr(i));
				end;
				if SameText(operator, '>') then begin
					if not (floatValue > floatCompareValue) then
						filteredOutRowsList.Add(IntToStr(i));
				end;
				if SameText(operator, '>=') then begin
					if not (floatValue >= floatCompareValue) then
						filteredOutRowsList.Add(IntToStr(i));
				end;
			end;
			
			inc(i);
		end;

		//DebugLog('filteredOutRowsList: ' + filteredOutRowsList.Text);
		
		if filteredOutRowsList.Count > 0 then begin 
			newlyFilteredOutRowCount := SetManualFilterToTable(table, 1, filterId, filteredOutRowsList, false);
		end;
	
	finally
		filteredOutRowsList.Free;
		filteredOutRowsList := nil;
	end;
	
	//return the number of newly filtered out rows
	Result := newlyFilteredOutRowCount;
		
	LogFunctionEnd;
end;

//=========================================================================
//  Get the number of rows 
//=========================================================================
function GetUnfilteredTableRowCount(const table : TStringList; const withHeaders : Boolean;) : Integer;
begin
	//LogFunctionStart('GetUnfilteredTableRowCount');
	
	Result := StrToInt(TStringList(table.Objects[0]).Names[0]);
	if withHeaders then begin 
		if TableHasHeaders(table) then begin
			inc(Result);
		end;
	end;
		
	//LogFunctionEnd;
end;

//=========================================================================
//  returns true if this row is filtered out
//	needs the original rowIndex the row had before any filters as parameters
//=========================================================================
function TableRowIsFilteredOut(const table : TStringList; const unfilteredRowIndex : Integer;) : Boolean;
begin
	//LogFunctionStart('TableRowIsFilteredOut');
	
	Result := (TStringList(table.Objects[1]).IndexOf(IntToStr(unfilteredRowIndex)) < 0);
	
	//LogFunctionEnd;
end;

//=========================================================================
//  returns true if there are any active filters on the table
//=========================================================================
function TableHasActiveFilters(const table : TStringList;) : Boolean;
begin
	//LogFunctionStart('TableHasActiveFilters');
	
	Result := (TStringList(table.Objects[4]).Count > 0);
	
	//LogFunctionEnd;
end;

//=========================================================================
//  try to change a table column's data type
//	(will throw an error if called with anything else than "String", "Float", "Boolean" or "Integer")
//=========================================================================
function TrySetTableColumnDataType(const table : TStringList; const colIndexOrHeader : Variant; const dataTypeStr : String; const allowEmptyValues : Boolean;) : Boolean;
var
	newDatatype, maxDatatype, currentDatatype, colIndex : Integer;
begin
	//LogFunctionStart('TrySetTableColumnDataType');
	
	Result := false;
	
	newDatatype := StringDataTypeToIntDataType(dataTypeStr);
	colIndex := TableColIndexByVariant(table, colIndexOrHeader);
	
	if newDatatype = 1 then begin //String is never a problem
		Result := true;
	end else begin
		currentDatatype := GetTableColumnDataType(table, colIndex);
		if currentDatatype = newDatatype then begin 
			Result := true;
		end else begin 
			if (currentDatatype = 9) and (newDatatype = 3) then begin //Float is less specific than Integer, so no problem
				Result := true;
			end else begin 
				maxDatatype := GetMostSpecificDataTypeForTableColumn(table, colIndex, allowEmptyValues);
				if maxDatatype = 0 then begin //if everything is allowed, simply do it
					Result := true;
				end else begin
					if maxDatatype = newDatatype then begin 
						Result := true;
					end else begin 
						if (maxDatatype= 9) and (newDatatype = 3) then begin //Float is less specific than Integer, so no problem
							Result := true;
						end;
					end;
				end;
			end;
		end;
	end;
	
	if Result then 
		table.Values[Format('dt%d',[colIndex])] := IntToStr(newDatatype);
	
	//LogFunctionEnd;
end;

//=========================================================================
//  automatically set the data types of all table columns to the most specific data type supporting the content now present
//=========================================================================
procedure DetermineTableColumnDatatypesByContents(const table : TStringList; const allowEmptyValues : Boolean;);
var
	j, colCount, datatype  : Integer;
begin
	//LogFunctionStart('DetermineTableColumnDatatypesByContents');
	
	colCount := GetTableColCount(table);
	
	j := 1;
	while j <= colCount do begin 
		datatype := GetMostSpecificDataTypeForTableColumn(table, j, allowEmptyValues);
		if datatype = 0 then //when the whole column is empty, keep it to string
			datatype := 1;
		table.Values[Format('dt%d',[j])] := IntToStr(datatype);
		
		inc(j);
	end;
	
	//LogFunctionEnd;
end;

//=========================================================================
//  get the most specific data type that the contents of one specific column of a table supports
//	this function will also respect filtered out rows, which are hidden from sight at the moment
//=========================================================================
function GetMostSpecificDataTypeForTableColumn(const table : TStringList; const colIndexOrHeader : Variant; const allowEmptyValues : Boolean;) : Integer;
const 
	decimalSeparator = '.';
var
	i, colIndex, unfilteredRowCount, filteredRowIndex, datatype  : Integer;
	curVal : String;
	oneRowIsEmpty, oneRowIsNotNumeric, oneRowContainsDecimalPlaces, oneRowIsNotBoolean : Boolean;
begin
	//LogFunctionStart('GetMostSpecificDataTypeForTableColumn');
	
	colIndex := TableColIndexByVariant(table, colIndexOrHeader);
	unfilteredRowCount := GetUnfilteredTableRowCount(table, false);
	
	
	datatype := 0; //unknown
	oneRowIsEmpty := false; //if true -> String
	oneRowIsNotBoolean := false; //if true -> Float, Int or String
	oneRowIsNotNumeric := false; //if true -> Boolean or String
	oneRowContainsDecimalPlaces := false; // if true -> Float or String
	i := 1;
	while i <= unfilteredRowCount do begin
		filteredRowIndex := TranslateUnfilteredToFilteredTableIndex(table, i, 1);
		curVal := table.Values[Format('%d|%d', [filteredRowIndex, colIndex])];
		
		if SameText(curVal, '') then begin 	
			oneRowIsEmpty := true;
		end else begin
			if not oneRowIsNotBoolean then 
				oneRowIsNotBoolean := (not (SameText(curVal, 'true') or SameText(curVal, 'false')));
			if not oneRowIsNotNumeric then
				oneRowIsNotNumeric := (not IsNumeric(curVal));
			if not oneRowContainsDecimalPlaces then 
				oneRowContainsDecimalPlaces := (Pos(decimalSeparator, curVal));
		end;
		
		if (not allowEmptyValues) and oneRowIsEmpty then begin
			datatype := 1; //String
			break;
		end;
		
		if oneRowIsNotNumeric and oneRowIsNotBoolean then begin
			datatype := 1; //String
			break;
		end;
		
		inc(i);
	end;
	
	if datatype = 0 then begin
		//first check basically says: if everything is empty and empty values are allowed: return "unknown"
		if oneRowIsEmpty and (not oneRowIsNotBoolean) and (not oneRowIsNotNumeric) and (not oneRowContainsDecimalPlaces) then begin 
			datatype := 0; //unknown
		end else begin
			if not oneRowIsNotBoolean then begin
				datatype := 8; //Boolean
			end else begin
				if oneRowIsNotNumeric then begin
					datatype := 1; //String
				end else begin
					if oneRowContainsDecimalPlaces then begin
						datatype := 3; //Float
					end else begin
						datatype := 9; //Integer
					end;
				end;
			end;
		end;
	end;
		
	Result := datatype;
	
	//LogFunctionEnd;
end;

//=========================================================================
//  get the data type as Integer by its string representation
//=========================================================================
function StringDataTypeToIntDataType( const dataTypeStr : String;) : Integer;
begin
	//LogFunctionStart('GetTableColumnDataTypeAsString');
	
	if SameText(dataTypeStr, 'String') then begin
		Result := 1;
	end else begin
		if SameText(dataTypeStr, 'Integer') then begin
			Result := 9;
		end else begin
			if SameText(dataTypeStr, 'Float') then begin
				Result := 3;
			end else begin
				if SameText(dataTypeStr, 'Boolean') then begin
					Result := 8;
				end else begin
					raise Exception.Create('Data type is not suppored by Table implementation. Data type: %s (Supported types: "String", "Integer", "Boolean", "Float")');
				end;
			end;
		end;
	end;
	
	//LogFunctionEnd;
end;

//=========================================================================
//  get the data type of a column as string representation
//=========================================================================
function GetTableColumnDataTypeAsString(const table : TStringList; const colIndexOrHeader : Variant;) : String;
var
	datatype  : Integer;
begin
	//LogFunctionStart('GetTableColumnDataTypeAsString');
	
	datatype := GetTableColumnDataType(table, colIndexOrHeader);
	
	//(the numbers are not really important, therefore they align with enums I used in my formula-parser)
	case datatype of 
		1: Result := 'String';
		3: Result := 'Float';
		8: Result := 'Boolean';
		9: Result := 'Integer';
	end;
	
	//LogFunctionEnd;
end;

//=========================================================================
//  get the data type of a column as integer enum
//	(the numbers are not really important, therefore they align with enums I used in my formula-parser)
//=========================================================================
function GetTableColumnDataType(const table : TStringList; const colIndexOrHeader : Variant;) : Integer;
var
	colIndex  : Integer;
begin
	//LogFunctionStart('GetTableColumnDataType');
	
	if table.Count = 0 then 
		raise Exception.Create('Table contains no data.');
	
	colIndex := TableColIndexByVariant(table, colIndexOrHeader);
	Result := StrToInt(table.Values[Format('dt%d',[colIndex])]);
	
	//LogFunctionEnd;
end;

//=========================================================================
//  convert a string list into an internal table structure
//	(the data type for all columns will be set to "String")
//=========================================================================
procedure StringListToTable(const list : TStringList; const columnDelimiter, fieldEncloser, escapedFieldEncloser : String; const hasHeaders :Boolean; table : TStringList;);
var
	tmpStr, curRow, curVal, newHeaderWithoutCounter, newHeader : String;
	i, j, rowCount, colCount, tmpInt, tmpInt2, searchIndex, colIndex, rowIndex, counter : Integer;
	columnsOfOneRow, headers : TStringList;
begin
	LogFunctionStart('StringListToTable');
	
	columnsOfOneRow := TStringList.Create;
	headers := TStringList.Create;
	headers.Sorted := true; //so that .Find() works
	
	try
		NewEmptyTable(table, hasHeaders);
		
		rowCount := list.Count;
		
		if hasHeaders then begin
			TStringList(table.Objects[1]).Strings[0] := Format('c=%d', [rowCount - 1]);
		end else begin
			TStringList(table.Objects[1]).Strings[0] := Format('c=%d', [rowCount]); 
		end;
		
		i := 0;
		while i < rowCount do begin
			curRow := list[i];
			
			StringToStringList(curRow, columnDelimiter, fieldEncloser, columnsOfOneRow, false);
			
			tmpInt := columnsOfOneRow.Count;
			colCount := max(colCount, tmpInt);
			j := 0;
			while j < tmpInt do begin
				curVal := columnsOfOneRow[j];
				//unescape string if it is escaped
				if not SameText(fieldEncloser,'') then begin
					if SameText(Copy(curVal, 1, 1), fieldEncloser) then
						curVal := StringReplace(Copy(curVal, 2, Length(curVal) - 2), escapedFieldEncloser, fieldEncloser, [rfIgnoreCase,rfReplaceAll]);
				end;
				
				colIndex := j + 1;
				
				if hasHeaders and (i = 0) then begin
					//save headers 
					
					//get next free unique header
					if SameText(curVal, '') then begin 
						newHeaderWithoutCounter := 'Column';
						curVal := 'Column1';
					end else begin 
						newHeaderWithoutCounter := curVal;
					end;
						
					counter := 1;
					while headers.Find(curVal, tmpInt2) do begin
						inc(counter);
						curVal := Format('%s%d',[newHeaderWithoutCounter, counter]);
					end;			
					headers.Add(curVal);
					table.Add(Format('h%d=%s',[colIndex, curVal]));
				end else begin
					if hasHeaders then begin
						rowIndex := i;
					end else begin 
						rowIndex := i + 1;
					end;
					
					//save cell value 
					//(it is not necessary to store empty cells)
					if not SameText(curVal, '') then 
						table.Add(Format('%d|%d=%s',[rowIndex, colIndex, curVal]));
				end;
				
				inc(j);
			end;
			
			
			inc(i);
		end;
		
		
		TStringList(table.Objects[2]).Strings[0] := IntToStr(colCount);
		
		if hasHeaders then begin 
			TStringList(table.Objects[0]).Strings[0] := Format('%d=%d', [rowCount - 1, colCount]);
		end else begin
			TStringList(table.Objects[0]).Strings[0] := Format('%d=%d', [rowCount, colCount]);
		end;
		
		j := 1;
		while j <= colCount do begin
			table.Add(Format('dt%d=1',[j]));
			inc(j);
		end;
		
	finally
		columnsOfOneRow.Free;
		columnsOfOneRow := nil;
		headers.Free;
		headers := nil;
	end;
	
	LogFunctionEnd;
end;

//=========================================================================
//  convert a CSV string into an internal table structure
//	(the data type for all columns will be set to "String")
//=========================================================================
procedure CsvStringToTable(const csvString, rowDelimiter, columnDelimiter, fieldEncloser, escapedFieldEncloser : String; const hasHeaders :Boolean; table : TStringList;);
var
	rowList : TStringList;
begin
	LogFunctionStart('CsvStringToTable');
	
	rowList := TStringList.Create;
	
	try
		StringToStringList(csvString, rowDelimiter, fieldEncloser, rowList, false);
		StringListToTable(rowList, columnDelimiter, fieldEncloser, escapedFieldEncloser, hasHeaders, table);
		
	finally
		rowList.Free;
		rowList := nil;
	end;
	
	LogFunctionEnd;
end;

//=========================================================================
//  convert an internal table structure into a normal TStringList where every row is a row in the list
//=========================================================================
procedure TableToStringList(const table : TStringList; const rowDelimiter, columnDelimiter, fieldEncloser, escapedFieldEncloser : String; const withHeaders :Boolean; list : TStringList;);
var
	curRow, curVal, datatype : String;
	i, j, rowCount, colCount : Integer;
	hasHeaders : Boolean;
begin
	LogFunctionStart('TableToStringList');
	
	list.Clear;
	
	if table.Count = 0 then 
		raise Exception.Create('Table contains no data.');
	
	rowCount := GetTableRowCount(table, false);
	colCount := GetTableColCount(table);
	
	if withHeaders then 
		hasHeaders := TableHasHeaders(table);
	
	if withHeaders and hasHeaders then begin
		i := 0;
	end else begin
		i := 1;
	end;
	
	while i <= rowCount do begin
		curRow := '';
		
		j := 1;
		while j <= colCount do begin
			if i = 0 then begin //header row
				curVal := TableHeaderByColIndex(table, j);
			end else begin
				curVal := GetTableCellValueAsString(table, i, j);
				datatype := GetTableColumnDataType(table, j);
				if datatype > 1 then begin //if the cell is not set, but the cell-value is not string, return the default value
					if SameText(curVal, '') then begin 
						case datatype of 
							3,9 : curVal := '0';
							8: curVal := 'false';
						end;
					end;
				end;
			end;
			
			//escape the value of the csv like row if necessary
			curVal := EscapeStringIfNecessary(curVal, rowDelimiter, columnDelimiter, fieldEncloser, escapedFieldEncloser);
			
			if j = 1 then begin
				curRow := curRow + curVal;
			end else begin
				curRow := curRow + columnDelimiter + curVal;
			end;
			inc(j);
		end;
		
		list.Add(curRow);
		inc(i);
	end;
	
	LogFunctionEnd;
end;

//=========================================================================
//  convert an internal table structure into a CSV string
//=========================================================================
function TableToCsvString(const table : TStringList; const rowDelimiter, columnDelimiter, fieldEncloser, escapedFieldEncloser : String; const withHeaders :Boolean;) : String;
var
	curRow : String;
	i : Integer;
	rowList : TStringList;
begin
	LogFunctionStart('TableToCsvString');
	
	rowList := TStringList.Create;
	
	try
		TableToStringList(table, rowDelimiter, columnDelimiter, fieldEncloser, escapedFieldEncloser, withHeaders, rowList);
		
		Result := '';
		i := 0;
		while i < rowList.Count do begin
			curRow := rowList[i];
			
			if i = 0 then begin
				Result := curRow;
			end else begin
				Result := Result + rowDelimiter + curRow;
			end;
			
			inc(i);
		end;
	
	finally
		rowList.Free;
		rowList := nil;
	end;
	
	LogFunctionEnd;
end;

//=========================================================================
//  get a specific row from a table
// 	rowIndex is 1-based - call with rowIndex 0 if the table has headers and you want to return the headers
//	rowIndex is the filtered index in case there are filters active
//=========================================================================
function GetTableRowAsString(const table : TStringList; const rowDelimiter, columnDelimiter, fieldEncloser, escapedFieldEncloser : String; const rowIndex : Integer;) : String;
var
	j, colCount : Integer;
	curVal : String;
begin
	//LogFunctionStart('GetTableRowAsString');
	
	if table.Count = 0 then 
		raise Exception.Create('Table contains no data.');
	colCount := GetTableColCount(table);
	
	if rowIndex = 0 then begin
		if not TableHasHeaders(table) then 
			raise Exception.Create('Table has no headers, but function "GetTableRowAsString" was called with rowIndex 0.');
	end;
	
	Result := '';
	
	j := 1;
	while j <= colCount do begin
		if rowIndex = 0 then begin //header row
			curVal := TableHeaderByColIndex(table, j);
		end else begin
			curVal := GetTableCellValueAsString(table, rowIndex, j);
		end;
		
		//escape the value of the csv like row if necessary
		curVal := EscapeStringIfNecessary(curVal, rowDelimiter, columnDelimiter, fieldEncloser, escapedFieldEncloser);
		
		if j = 1 then begin
			Result := Result + curVal;
		end else begin
			Result := Result + columnDelimiter + curVal;
		end;
		inc(j);
	end;
	
	//LogFunctionEnd;
end;

//=========================================================================
//  get a specific column from a table
// 	colIndex is 1-based
//	if you call it with withHeaders=true and there are none, it will simply return the column without headers
//=========================================================================
function GetTableColumnAsString(const table : TStringList; const rowDelimiter, columnDelimiter, fieldEncloser, escapedFieldEncloser : String; const colIndexOrHeader : Variant; const withHeaders : Boolean;) : String;
var
	i, rowCount, counter, colIndex : Integer;
	curVal : String;
	hasHeaders : Boolean;
begin
	//LogFunctionStart('GetTableColumnAsString');
	
	if table.Count = 0 then 
		raise Exception.Create('Table contains no data.');
	
	colIndex := TableColIndexByVariant(table, colIndexOrHeader);

	rowCount := GetTableRowCount(table, false);
	if withHeaders then 
		hasHeaders := TableHasHeaders(table);
	
	if withHeaders and hasHeaders then begin
		i := 0;
	end else begin
		i := 1;
	end;
	
	Result := '';
	while i <= rowCount do begin
		if i = 0 then begin //header row
			curVal := TableHeaderByColIndex(table, colIndex);
		end else begin
			curVal := GetTableCellValueAsString(table, i, colIndex);
		end;
		
		//escape the value of the csv like row if necessary
		curVal := EscapeStringIfNecessary(curVal, rowDelimiter, columnDelimiter, fieldEncloser, escapedFieldEncloser);
		
		if counter = 0 then begin
			Result := Result + curVal;
		end else begin
			Result := Result + rowDelimiter + curVal;
		end;
		inc(counter);
		inc(i);
	end;

	//LogFunctionEnd;
end;

//=========================================================================
//  get a specific row from a table
// 	rowIndex is 1-based - call with rowIndex 0 if the table has headers and you want to return the headers
//	rowIndex is the filtered index in case there are filters active
//	the string values in the list will not be escaped
//=========================================================================
procedure GetTableRowAsList(const table : TStringList; const rowIndex : Integer; list : TStringList);
var
	j, colCount : Integer;
	curVal : String;
begin
	//LogFunctionStart('GetTableRowAsList');
	
	if table.Count = 0 then 
		raise Exception.Create('Table contains no data.');
	
	colCount := GetTableColCount(table);
	
	if rowIndex = 0 then begin
		if not TableHasHeaders(table) then 
			raise Exception.Create('Table has no headers, but function "GetTableRowAsList" was called with rowIndex 0.');
	end;
	
	j := 1;
	while j <= colCount do begin
		if rowIndex = 0 then begin //header row
			curVal := TableHeaderByColIndex(table, j);
		end else begin
			curVal := GetTableCellValueAsString(table, rowIndex, j);
		end;
		
		list.Add(curVal);
		inc(j);
	end;
	
	//LogFunctionEnd;
end;

//=========================================================================
//  get a specific column from a table
// 	colIndex is 1-based
//	if you call it with withHeaders=true and there are none, it will simply return the column without headers
//	the string values in the list will not be escaped
//=========================================================================
procedure GetTableColumnAsList(const table : TStringList; const rowDelimiter, columnDelimiter, fieldEncloser, escapedFieldEncloser : String; const colIndexOrHeader : Variant; const withHeaders : Boolean; list : TStringList;);
var
	i, rowCount, colIndex : Integer;
	curVal : String;
	hasHeaders : Boolean;
begin
	//LogFunctionStart('GetTableColumnAsList');
	
	if table.Count = 0 then 
		raise Exception.Create('Table contains no data.');
	
	colIndex := TableColIndexByVariant(table, colIndexOrHeader);
	rowCount := GetTableRowCount(table, false);
	if withHeaders then 
		hasHeaders := TableHasHeaders(table);
	
	if withHeaders and hasHeaders then begin
		i := 0;
	end else begin
		i := 1;
	end;
	
	while i <= rowCount do begin
		if i = 0 then begin //header row
			curVal := TableHeaderByColIndex(table, colIndex);
		end else begin
			curVal := GetTableCellValueAsString(table, i, colIndex);
		end;
		
		list.Add(curVal);
		inc(i);
	end;

	//LogFunctionEnd;
end;

//=========================================================================
//  get a specific value from a table
// 	rowIndex and colIndex are 1-based
//	rowIndex is the filtered index in case there are filters active
//	if you call it with rowIndex=0 it will return the header. If there are no headers it will throw an error.
//	if you call it with a rowIndex or colIndex that does not exist, the result will be an empty string 
// 	the value will not be escaped
//=========================================================================
function GetTableCellValueAsString(const table : TStringList; const rowIndex : Integer; const colIndexOrHeader : Variant;) : String;
var 
	colIndex : Integer;
begin
	//LogFunctionStart('GetTableCellValueAsString');
	
	if table.Count = 0 then 
		raise Exception.Create('Table contains no data.');
	
	if rowIndex = 0 then begin
		if not TableHasHeaders(table) then 
			raise Exception.Create('Table has no headers, but rowIndex was 0 when trying to get a value.');
	end;
	
	colIndex := TableColIndexByVariant(table, colIndexOrHeader);
	
	if rowIndex = 0 then begin 
		Result := TableHeaderByColIndex(table, colIndex);
	end else begin
		Result := table.Values[Format('%d|%d',[rowIndex, colIndex])];
	end;
	
	//LogFunctionEnd;
end;

//=========================================================================
//  get a specific value from a table
// 	rowIndex and colIndex are 1-based
//	rowIndex is the filtered index in case there are filters active
//	if you call it with rowIndex=0 it will return the header. If there are no headers it will throw an error.
//	if you call it with a rowIndex or colIndex that does not exist, the result will be an empty string 
//	will return the data type that the column has
// 		a string value will not be escaped
//		empty Boolean values will be "false"
//		empty Integer values will be 0
//		empty Float values will be 0.0
//=========================================================================
function GetTableCellValue(const table : TStringList; const rowIndex : Integer; const colIndexOrHeader : Variant;) : Variant;
var 
	colIndex, datatype : Integer;
begin
	//LogFunctionStart('GetTableCellValue');
	
	colIndex := TableColIndexByVariant(table, colIndexOrHeader);
	if rowIndex = 0 then begin
		Result := TableHeaderByColIndex(table, colIndex);
	end else begin 
		datatype := GetTableColumnDataType(table, colIndex);
		
		case datatype of 
			1: Result := GetTableCellValueAsString(table, rowIndex, colIndex);
			3: Result := GetTableCellValueAsFloat(table, rowIndex, colIndex);
			8: Result := GetTableCellValueAsBool(table, rowIndex, colIndex);
			9: Result := GetTableCellValueAsInt(table, rowIndex, colIndex);
		end;
	end;
			
	//LogFunctionEnd;
end;


//=========================================================================
//  get a specific value from a table
// 	rowIndex and colIndex are 1-based
//	rowIndex is the filtered index in case there are filters active
//	if you call it with rowIndex=0 it will return the header. If there are no headers it will throw an error.
//	if you call it with a rowIndex or colIndex that does not exist, the result will be an empty string 
// 	a string value will not be escaped
//	if the value is not Boolean (or the string value is not "true") it returns false
//=========================================================================
function GetTableCellValueAsBool(const table : TStringList; const rowIndex : Integer; const colIndexOrHeader : Variant;) : Boolean;
var
	tmpStr : String;
begin
	//LogFunctionStart('GetTableCellValueAsBool');
	
	Result := SameText(GetTableCellValueAsString(table, rowIndex, colIndexOrHeader), 'true');
		
	//LogFunctionEnd;
end;

//=========================================================================
//  get a specific value from a table
// 	rowIndex and colIndex are 1-based
//	rowIndex is the filtered index in case there are filters active
//	if you call it with rowIndex=0 it will return the header. If there are no headers it will throw an error.
//	if you call it with a rowIndex or colIndex that does not exist, the result will be an empty string 
// 	a string value will not be escaped
//	if the value is not numeric a Double containing 0.0 will be returned
//=========================================================================
function GetTableCellValueAsFloat(const table : TStringList; const rowIndex : Integer; const colIndexOrHeader : Variant;) : Double;
var
	tmpStr : String;
begin
	//LogFunctionStart('GetTableCellValueAsFloat');
	
	tmpStr := GetTableCellValueAsString(table, rowIndex, colIndexOrHeader);
	if IsNumeric(tmpStr) then begin
		Result := StrToFloat(Result);
	end else begin
		Result := 0.0;
	end;
		
	//LogFunctionEnd;
end;

//=========================================================================
//  get a specific value from a table
// 	rowIndex and colIndex are 1-based
//	rowIndex is the filtered index in case there are filters active
//	if you call it with rowIndex=0 it will return the header. If there are no headers it will throw an error.
//	if you call it with a rowIndex or colIndex that does not exist, the result will be an empty string 
// 	a string value will not be escaped
//	if the value is not numeric a 0 will be returned
//	if the value contains decimal places, the value before the decimal place will be returned 
//=========================================================================
function GetTableCellValueAsInt(const table : TStringList; const rowIndex : Integer; const colIndexOrHeader : Variant;) : Integer;
var
	tmpStr : String;
begin
	//LogFunctionStart('GetTableCellValueAsInt');
	
	tmpStr := GetTableCellValueAsString(table, rowIndex, colIndexOrHeader);
	if IsNumeric(tmpStr) then begin
		Result := Trunc(StrToFloat(Result));
	end else begin
		Result := 0;
	end;
		
	//LogFunctionEnd;
end;

//=========================================================================
//  set a specific value from a table
// 	rowIndex and colIndex are 1-based
//	rowIndex is the filtered index in case there are filters active
//	if you call it with rowIndex=-1 it will set the value for all rows in the table
//	if you call it with colIndex=-1 it will set the value for all columns in the table
//	if you call it with a rowIndex or colIndex that is not -1 and does not exist, no change is done
// 	headers (in case the table has some), will never be changed by this function
//=========================================================================
procedure SetTableCellValueString (const table : TStringList; const rowIndex : Integer; const colIndexOrHeader : Variant; const newValue : String;);
var 
	i, j, rowCount, colCount, colIndex : Integer;
begin
	//LogFunctionStart('SetTableCellValueString');
	
	colIndex := TableColIndexByVariant(table, colIndexOrHeader);
	
	if table.Count = 0 then 
		raise Exception.Create('Table contains no data.');
	
	if rowIndex = 0 then
		raise Exception.Create('Setting a table value was called with rowIndex 0, which is not allowed.');
	if colIndex = 0 then
		raise Exception.Create('Setting a table value was called with colIndex 0, which is not allowed.');
	
	colCount := GetTableColCount(table);
	
	//avoid unneccessary looping
	if not (rowIndex = -1) then begin
		rowCount := rowIndex;
		i := rowIndex;
	end else begin
		rowCount := GetTableRowCount(table, false);
		i := 1;
	end;
	while i <= rowCount do begin
		if ((i = rowIndex) or (rowIndex = -1)) then begin 
			j := 1;
			while j <= colCount do begin
				if (j = colIndex) or (colIndex = -1) then begin
					table.Values[Format('%d|%d',[rowIndex, j])] := newValue;
				end;
				inc(j);
			end;
		end;
		inc(i);
	end;
	
	//LogFunctionEnd;
end;


//=========================================================================
//  set a specific value from a table
// 	rowIndex and colIndex are 1-based
//	rowIndex is the filtered index in case there are filters active
//	if you call it with rowIndex=-1 it will set the value for all rows in the table
//	if you call it with colIndex=-1 it will set the value for all columns in the table
//	if you call it with a rowIndex or colIndex that is not -1 and does not exist, no change is done
// 	headers (in case the table has some), will never be changed by this function
//=========================================================================
procedure SetTableCellValueBool (const table : TStringList; const rowIndex : Integer; const colIndexOrHeader : Variant; const newValue : Boolean;);
begin
	//LogFunctionStart('SetTableCellValueBool');
	
	if newValue then begin 
		SetTableCellValueString(table, rowIndex, colIndexOrHeader, 'true');
	end else begin
		SetTableCellValueString(table, rowIndex, colIndexOrHeader, 'false');
	end;
	
	//LogFunctionEnd;
end;


//=========================================================================
//  set a specific value from a table
// 	rowIndex and colIndex are 1-based
//	rowIndex is the filtered index in case there are filters active
//	if you call it with rowIndex=-1 it will set the value for all rows in the table
//	if you call it with colIndex=-1 it will set the value for all columns in the table
//	if you call it with a rowIndex or colIndex that is not -1 and does not exist, no change is done
// 	headers (in case the table has some), will never be changed by this function
//=========================================================================
procedure SetTableCellValueInt (const table : TStringList; const rowIndex : Integer; const colIndexOrHeader : Variant; const newValue : Integer;);
begin
	//LogFunctionStart('SetTableCellValueInt');
	
	SetTableCellValueString(table, rowIndex, colIndexOrHeader, IntToStr(newValue));
	
	//LogFunctionEnd;
end;

//=========================================================================
//  set a specific value from a table
// 	rowIndex and colIndex are 1-based
//	rowIndex is the filtered index in case there are filters active
//	if you call it with rowIndex=-1 it will set the value for all rows in the table
//	if you call it with colIndex=-1 it will set the value for all columns in the table
//	if you call it with a rowIndex or colIndex that is not -1 and does not exist, no change is done
// 	headers (in case the table has some), will never be changed by this function
//	when storing the float value, precision is cut to 10 decimal places
//=========================================================================
procedure SetTableCellValueFloat (const table : TStringList; const rowIndex : Integer; const colIndexOrHeader : Variant; const newValue : Double;);
begin
	//LogFunctionStart('SetTableCellValueInt');
	
	SetTableCellValueString(table, rowIndex, colIndexOrHeader, FormatFloat('0.##########;-0.##########;"0"', newValue));
	
	//LogFunctionEnd;
end;


//=========================================================================
//  set a specific value from a table
// 	rowIndex and colIndex are 1-based
//	rowIndex is the filtered index in case there are filters active
//	if you call it with rowIndex=-1 it will set the value for all rows in the table
//	will throw an error if you call it with colIndex=-1 
//	if you call it with a rowIndex or colIndex that is not -1 and does not exist, no change is done
// 	headers (in case the table has some), will never be changed by this function
// 	expects the correct data type for the column to be changed, will result in errors, if the wrong data type is used
//=========================================================================
procedure SetTableCellValue (const table : TStringList; const rowIndex : Integer; const colIndexOrHeader : Variant; const newValue : Variant;);
var 
	i, datatype, rowCount, colCount, colIndex, intValue : Integer;
	floatValue : Double;
	stringValue : String;
	boolValue : Boolean;
begin
	//LogFunctionStart('SetTableCellValue');
	
	colIndex := TableColIndexByVariant(table, colIndexOrHeader);
	
	colCount := GetTableColCount(table);
	
	if (colIndex < 1) or (colIndex > colCount) then 
		raise Exception.Create(Format('Column does not exist in table. Column-index: %d', [colIndex]));
		
	datatype := GetTableColumnDataType(table, colIndex);
	
	case datatype of 
		1: stringValue := newValue;
		3: floatValue := newValue;
		8: boolValue := newValue;
		9: intValue := newValue;
	end;
	
	//avoid useless loop if not necessary
	if not (rowIndex = -1) then begin
		rowCount := rowIndex;
		i := rowIndex
	end else begin
		rowCount := GetTableRowCount(table, false);
		i := 1;
	end;
	while i <= rowCount do begin
		if ((i = rowIndex) or (rowIndex = -1)) then begin 
			case datatype of 
				1: begin 
						SetTableCellValueString(table, i, colIndex, stringValue);
					end;
				3: begin 
						SetTableCellValueFloat(table, i, colIndex, floatValue);
					end;
				8: begin 
						SetTableCellValueBool(table, i, colIndex, boolValue);
					end;
				9: begin 
						SetTableCellValueInt(table, i, colIndex, intValue);
					end;
			end;
		end;
		inc(i);
	end;
	
	//LogFunctionEnd;
end;

//=========================================================================
//  get the row count from a table
// 	if you call this function with withHeaders=true and there are no headers, then it will simply return the rowCount without headers
//	this function returns the filtered row count - the one you would see if it was in Excel
//=========================================================================
function GetTableRowCount(const table : TStringList; const withHeaders : Boolean;) : Integer;
begin
	//LogFunctionStart('GetTableRowCount');
	
	if table.Count = 0 then 
		raise Exception.Create('Table contains no data.');

	// debugLog(TStringList(table.Objects[1]).Text);

	Result := StrToInt(TStringList(table.Objects[1]).ValueFromIndex[0]);
	
	if withHeaders then begin 
		if TableHasHeaders(table) then 
			inc(Result);
	end;
	
	//LogFunctionEnd;
end;

//=========================================================================
//  get the column count from a table
//=========================================================================
function GetTableColCount(const table : TStringList;) : Integer;
begin
	//LogFunctionStart('GetTableColCount');
	
	if table.Count = 0 then 
		raise Exception.Create('Table contains no data.');
	
	Result := StrToInt(TStringList(table.Objects[2]).Strings[0]);
	
	//LogFunctionEnd;
end;

//=========================================================================
//  get the header row from a table
// 	if you call this function for a table that has no headers it will throw an exception
//=========================================================================
function GetTableHeaderRowAsString(const table : TStringList; const rowDelimiter, columnDelimiter, fieldEncloser, escapedFieldEncloser : String;) : String;
var
	j, colCount : Integer;
	curVal : String;
begin
	//LogFunctionStart('GetTableHeaderRowAsString');
	
	if table.Count = 0 then 
		raise Exception.Create('Table contains no data.');
	
	colCount := GetTableColCount(table);
	
	if not TableHasHeaders(table) then 
		raise Exception.Create('Table has no headers, but there was an attempt to access the table via header.');

	Result := '';
	
	j := 1;
	while j <= colCount do begin
		curVal := table.Values[Format('h%d',[j])];
		
		//escape the value of the csv like row if necessary
		curVal := EscapeStringIfNecessary(curVal, rowDelimiter, columnDelimiter, fieldEncloser, escapedFieldEncloser);
		
		if j = 1 then begin
			Result := Result + curVal;
		end else begin
			Result := Result + columnDelimiter + curVal;
		end;
		inc(j);
	end;
	
	//LogFunctionEnd;
end;

//=========================================================================
//  get all headers from a table into a list
// 	if you call this function for a table that has no headers it will throw an exception
//=========================================================================
procedure GetTableHeadersAsList(const table : TStringList; headers : TStringList;);
var
	j, colCount : Integer;
begin
	//LogFunctionStart('GetTableHeadersAsList');
	
	if table.Count = 0 then 
		raise Exception.Create('Table contains no data.');
	
	colCount := GetTableColCount(table);
	
	if not TableHasHeaders(table) then 
		raise Exception.Create('Table has no headers, but there was an attempt to access the table via header.');

	headers.Clear;

	j := 1;
	while j <= colCount do begin
		headers.Add(table.Values[Format('h%d',[j])]);
		inc(j);
	end;
	
	//LogFunctionEnd;
end;

//=========================================================================
//  get next unique header by providing a suggested header
// 	if you call this function for a table that has no headers it will throw an exception
//	bevaves just like Excel:
//		if you call it with a suggested header that does already exist, then it will be enumerated with the next number that is not used up yet, starting with "2"
//		if you call it with an empty suggested header, then it will start with "Column1", then "Column2" and so on 
//=========================================================================
function GetNextUniqueTableHeader(const table : TStringList; const suggestedHeader : String) : String;
var
	counter, tmpInt : Integer;
	newHeaderWithoutCounter : String;
	headers : TStringList;
begin
	//LogFunctionStart('GetNextUniqueTableHeader');
	
	headers := TStringList.Create;
	headers.Sorted := true; // so that .Find() works
	
	try
		GetTableHeadersAsList(table, headers);
		
		newHeaderWithoutCounter := suggestedHeader;
		Result := suggestedHeader;
		
		if SameText(newHeaderWithoutCounter, '') then begin
			newHeaderWithoutCounter := 'Column';
			Result := 'Column1';
		end;
		
		counter := 1;
		while headers.Find(Result, tmpInt) do begin
			inc(counter);
			Result := Format('%s%d',[newHeaderWithoutCounter, counter]);
		end;
		
	finally
		headers.Free;
		headers := nil;
	end;
	//LogFunctionEnd;
end;

//=========================================================================
//  true if a table has headers
//=========================================================================
function TableHasHeaders(const table : TStringList;) : Boolean;
begin
	//LogFunctionStart('TableHasHeaders');
	
	if table.Count = 0 then 
		raise Exception.Create('Table contains no data.');
	
	Result := SameText(table.ValueFromIndex[3], 'true');
	
	//LogFunctionEnd;
end;

//=========================================================================
//  changes the header of a column and returns the new column header
//	if you try setting a header that does already exist, it will add a postfix so that it is unique, starting with "2"
//	if you try to set a header to empty string, it will automatically assign a free unique header, starting with "Column1", then "Column2", etc.
// 	if you try to set a header on a table that has no headers, it will throw an error
//=========================================================================
function SetTableColumnHeader(const table : TStringList; const colIndexOrHeader : Variant; const suggestedHeader : String) : String;
var 
	colIndex : Integer;
begin
	//LogFunctionStart('SetTableColumnHeader');
		
	if not TableHasHeaders(table) then 
		raise Exception.Create('Table has no headers, but it was attempted to change a header.');

	colIndex := TableColIndexByVariant(table, colIndexOrHeader);
	Result := GetNextUniqueTableHeader(table, suggestedHeader);
	table.Values[Format('h%d', [colIndex])] := Result;
	
	//LogFunctionEnd;
end;

//=========================================================================
//  removes the headers a table may have
//	if you call it on a table that has no headers, it will do nothing
// 	(it actually does not remove any headers. it just makes the table forget that it has headers.)
// 	(but be aware: you cannot restore these lost headers later on. If you switch headers on again using "AddTableHeaders" then they will be re-assigned with "Column1", "Column2", etc.)
//=========================================================================
procedure RemoveTableHeaders(const table : TStringList;);
begin
	//LogFunctionStart('RemoveTableHeaders');
	
	if table.Count = 0 then 
		raise Exception.Create('Table contains no data.');
	
	if TableHasHeaders(table) then begin 
		table.Values['hasHeaders'] := 'false';
	end;
	
	//LogFunctionEnd;
end;

//=========================================================================
//  adds headers to a table 
//	if you call it on a table that already has headers, it will do nothing
//	if the table had headers originally before they were removed, these original headers will not be present again
// 	All columns will automatically get headers, starting from "Column1", "Column2", etc.
//=========================================================================
procedure AddTableHeaders(const table : TStringList;);
const 
	newHeaderWithoutCounter = 'Column';
var 
	j, colCount : Integer;
begin
	//LogFunctionStart('AddTableHeaders');
		
	if not TableHasHeaders(table) then begin 
		table.Values['hasHeaders'] := 'true';
		
		colCount := GetTableColCount(table);
		
		j := 1;
		while j <= colCount do begin 
			table.Values[Format('h%d', [j])] := Format('%s%d', [newHeaderWithoutCounter, j]);
			inc(j);
		end;
	end;
	
	//LogFunctionEnd;
end;

//=========================================================================
//  get the index of the (first) column that has a specific header
//	returns -1 if it does not find the header
//	throws an error if the table has no headers
//=========================================================================
function TableHeaderToColIndex(const table : TStringList; const header : String;) : Integer;
var 
	j, colCount : Integer;
begin
	//LogFunctionStart('TableHeaderToColIndex');
	
	if table.Count = 0 then 
		raise Exception.Create('Table contains no data.');
	
	if not TableHasHeaders(table) then
		raise Exception.Create('Table has no headers, but there was an attempt to access the table via header.');
	
	Result := -1;
	
	colCount := GetTableColCount(table);
	
	j := 1;
	while j <= colCount do begin
		if SameText(table.Values[Format('h%d',[j])], header) then begin
			Result := j;
			break;
		end;
		inc(j);
	end;
	
	//LogFunctionEnd;
end;

//=========================================================================
//  get the header of a specific column by index 
//	returns empty string if called with a column index greater than the available columns
//	throws an error if the table has no headers
//	throws an error if the index is smaller than 1 
//=========================================================================
function TableHeaderByColIndex(const table : TStringList; const colIndex : Integer;) : String;
begin
	//LogFunctionStart('TableHeaderByColIndex');
	
	if table.Count = 0 then 
		raise Exception.Create('Table contains no data.');
	
	if not TableHasHeaders(table) then
		raise Exception.Create('Table has no headers, but there was an attempt to access the table via header.');
	
	if colIndex < 1 then
		raise Exception.Create(Format('Function "TableHeaderByColIndex" was called with a column-index smaller than 1, which is not allowed. Column-Index: %d',[colIndex]));
	
	Result := table.Values[Format('h%d',[colIndex])];
	
	//LogFunctionEnd;
end;

//=========================================================================
//  get the column index from the variant parameter that could represent the column index or the header name
//=========================================================================
function TableColIndexByVariant(const table : TStringList; const colIndexOrHeader : Variant;) : Integer;
var 
	header : String;
begin
	//LogFunctionStart('TableColIndexByVariant');
	
	case varType(colIndexOrHeader) of 
		varShortInt, varSmallint, varInteger: Result := colIndexOrHeader;
	else begin	
			header := colIndexOrHeader;
			Result := TableHeaderToColIndex(table, header);
			if Result = -1 then 
				raise Exception.Create(Format('Could not find header in table. Header: %s', [header]));
		end;
	end;
	
	//LogFunctionEnd;
end;


end.