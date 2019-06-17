﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Management.Automation;
using System.Text;
using System.Threading.Tasks;

namespace Sqlcollaborative.Dbatools.Database
{
    /// <summary>
    /// Simple representation of a backup file
    /// </summary>
    public class FileEntry : ICloneable
    {
        /// <summary>
        /// Type of the file
        /// </summary>
        public string FileType;

        /// <summary>
        /// Logical name of the file
        /// </summary>
        public string LogicalName;

        /// <summary>
        /// The full path of the file
        /// </summary>
        public string FullName;

        /// <summary>
        /// Creates an empty file entry
        /// </summary>
        public FileEntry()
        {

        }

        /// <summary>
        /// Creates a file entry from a psobject
        /// </summary>
        /// <param name="Object">The object to parse</param>
        public FileEntry(PSObject Object)
        {
            if ((Object.Properties.Where(o => String.Equals(o.Name, "FileType", StringComparison.InvariantCultureIgnoreCase)).Count() == 1) && (Object.Properties["FileType"].Value != null))
            {
                FileType = Object.Properties["FileType"].Value.ToString();
            }
            if ((Object.Properties.Where(o => String.Equals(o.Name, "LogicalName", StringComparison.InvariantCultureIgnoreCase)).Count() == 1) && (Object.Properties["LogicalName"].Value != null))
            {
                LogicalName = Object.Properties["LogicalName"].Value.ToString();
            }
            if ((Object.Properties.Where(o => String.Equals(o.Name, "FullName", StringComparison.InvariantCultureIgnoreCase)).Count() == 1) && (Object.Properties["FullName"].Value != null))
            {
                FullName = Object.Properties["FullName"].Value.ToString();
            }
        }

        /// <summary>
        /// Clones this item
        /// </summary>
        /// <returns>A true copy of itself</returns>
        public object Clone()
        {
            FileEntry result = new FileEntry();
            result.FileType = FileType;
            result.LogicalName = LogicalName;
            result.FullName = FullName;
            return result;
        }
    }
}
