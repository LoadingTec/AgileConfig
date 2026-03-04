import { getAppVer } from "@/utils/system";
import { GithubOutlined } from "@ant-design/icons"
import React from "react"

const LayoutFooter : React.FC =()=>{
    return (
        <div style={{
          display:'flex',
          justifyContent: 'center',
          marginBottom: '10px',
          color: '#bfbfbf'
        }}>
          &nbsp; Powered by AKO R&D 
          <a title={'AKO Config Center:' + getAppVer()} href="#" style={{color:'#bfbfbf'}}>@</a>
          v
          { getAppVer()}
          &nbsp;
        </div>
      )
}

export default LayoutFooter;